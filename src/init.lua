
local tokens = {
    {"commentToken", "^[\t\32]*#[^\n]+\n[\t\n\32]*"},
    {"setToken", "^[\t\n\32]*set[\t\n\32]+([%w_]+)[\t\n\32]*=[\t\n\32]*"},
    {"callToken", "^[\t\n\32]*([%w_]+)[\t\n\32]*=[\t\n\32]*([%w_]+)[\t\n\32]*%([\t\n\32]*([%w_]+)[\t\n\32]*%)"},
    {"sumToken", "^[\t\n\32]*([%w_1234567890]+)[\t\n\32]*%+[\t\n\32]*([%w_1234567890]+)[\t\n\32]*"},
    {"printToken", "^[\t\n\32]*print[\t\n\32]+([%w_]+)[\t\n\32]*"},
    {"returnToken", "^[\t\n\32]*return[\t\n\32]+([%w_]+)[\t\n\32]*"},
    {"numberToken", "^[\t\n\32]*([1234567890]+)[\t\n\32]*"},
    {"stringToken", '^"([^"]+)"'},
    {"endToken", "^[\t\n\32]*}"},
    {"spacesToken", "^[\t\n\32]+"},
}
local stringToken = tokens[8]
local sumToken = tokens[4]
local numberToken = tokens[7]

local funcToken = "^[\t\n\32]*func[\t\b\32]+([%w_]+)[\t\b\32]*{[\t\b\32]*"

local INST_SET = 0
local INST_SUM = 1
local INST_PRINT = 2
local INST_CALL = 3
local INST_RETURN = 4
local INST_LOADK = 5
local opNames = {
    [0] = "SET",
    [1] = "SUM",
    [2] = "PRINT",
    [3] = "CALL",
    [4] = "RETURN",
    [5] = "LOADK",
}

local TYPE_PTR = 0
local TYPE_CONST = 1

local function parseFunction(code,init)
    local pos = init
    local startAt,endAt,matched,matched2,matched3,thisToken
    local func = {
        op = {},
        const = {},
    }
    local ids = {}
    local idLength = 0
    local constIds = {}
    local constLength = 0

    local function getConstId(const)
        local id = constIds[const]
        if not id then
            constLength = constLength + 1
            constIds[const] = constLength
            id = constLength
        end
        func.const[id] = const
        return id
    end

    local function getId(name)
        if name == "arg" then return 0 end
        local id = ids[name]
        if not id then
            idLength = idLength + 1
            ids[name] = idLength
            id = idLength
        end
        return id
    end

    while true do
        for _,token in ipairs(tokens) do
            startAt,endAt,matched,matched2,matched3 = code:find(token[2],pos)
            if startAt then
                thisToken = token[1]
                break
            end
        end

        if thisToken == "endToken" then
            pos = endAt+1
            break
        elseif thisToken == "commentToken" then
            pos = endAt+1
        elseif thisToken == "setToken" then
            local id = getId(matched)

            local valueStartAt,valueEndAt,valueMatched
            valueStartAt,valueEndAt,valueMatched = code:find(stringToken[2],endAt+1)
            if valueStartAt then
                table.insert(func.op,{INST_LOADK,id,getConstId(valueMatched)})
                pos = valueEndAt+1

            else

                local x1,x2
                valueStartAt,valueEndAt,x1,x2 = code:find(sumToken[2],endAt+1)
                if valueStartAt then -- 더하기 시작

                    local value1,value2 = {},{}

                    if tonumber(x1) then
                        value1[1] = TYPE_CONST
                        value1[2] = tonumber(x1)
                    else
                        local valueId = getId(x1)
                        value1[1] = TYPE_PTR
                        value1[2] = valueId
                    end

                    if tonumber(x2) then
                        value2[1] = TYPE_CONST
                        value2[2] = tonumber(x2)
                    else
                        local valueId = getId(x2)
                        value2[1] = TYPE_PTR
                        value2[2] = valueId
                    end

                    table.insert(func.op,{INST_SUM,id,value1,value2})
                    pos = valueEndAt+1
                else
                    valueStartAt,valueEndAt,matched = code:find(numberToken[2],endAt+1)
                    table.insert(func.op,{INST_SET,id,tonumber(matched)})

                    pos = valueEndAt+1
                end

            end

        elseif thisToken == "printToken" then
            local id = getId(matched)
            table.insert(func.op,{INST_PRINT,id})
            pos = endAt+1
        elseif thisToken == "returnToken" then
            local id = getId(matched)
            table.insert(func.op,{INST_RETURN,id})
            pos = endAt+1
        elseif thisToken == "callToken" then
            local id = getId(matched)
            local id2 = getId(matched3)
            table.insert(func.op,{INST_CALL,matched2,id,id2})

            pos = endAt+1
        elseif thisToken == "sumToken" then
            error("예상못한 변수가 발생!")
        elseif thisToken == "numberToken" then
            error("예상못한 변수가 발생!")
        elseif thisToken == "stringToken" then
            error("예상못한 변수가 발생!")
        elseif thisToken == "spacesToken" then
            pos = endAt+1
        end

    end

    return func,pos
end

local function run(func,funcs,arg,depth)
    depth = depth or 1
    if depth > 200 then
        print("Too long loop")
        return
    end
    local opPosition = 1
    local mem = {[0] = arg}
    while true do
        local this = func.op[opPosition]
        if not this then
            return
        elseif this[1] == INST_LOADK then
            mem[this[2]] = func.const[this[3]]
        elseif this[1] == INST_RETURN then
            return mem[this[2]]
        elseif this[1] == INST_PRINT then
            print(mem[this[2]])
        elseif this[1] == INST_SET then
            mem[this[2]] = this[3]
        elseif this[1] == INST_SUM then
            local value1,value2
            if this[3][1] == TYPE_PTR then
                value1 = mem[this[3][2]]
            elseif this[3][1] == TYPE_CONST then
                value1 = this[3][2]
            end

            if this[4][1] == TYPE_PTR then
                value2 = mem[this[4][2]]
            elseif this[4][1] == TYPE_CONST then
                value2 = this[4][2]
            end

            mem[this[2]] = value1 + value2
        elseif this[1] == INST_CALL then
            local callfn = funcs[this[2]]
            local callarg = mem[this[4]]
            if type(callfn) == "function" then
                mem[this[3]] = callfn(callarg)
            else
                mem[this[3]] = run(callfn,funcs,callarg,depth+1)
            end
        end
        opPosition = opPosition + 1
    end
end

local function parse(code,init)
    local funcs = {}

    local pos = init or 1
    local startAt,endAt,matched
    while true do
        startAt,endAt,matched = code:find(funcToken,pos)
        if not startAt then
            return funcs
        end
        funcs[matched],pos = parseFunction(code,endAt+1)
    end

end

local function dumpParsed(parsed)
    local buffer = {}

    for funcName,func in pairs(parsed) do
        table.insert(buffer,("FUNC '%s'"):format(funcName))
        for i,v in ipairs(func.const) do
            table.insert(buffer,("CONST '%s'"):format(v))
        end
        for i,v in ipairs(func.op) do
            table.insert(buffer,("%s %s"):format(opNames[v[1]],table.concat(v," ",2,#v)))
        end
    end
    return table.concat(buffer,"\n")
end

local function runcode(code)
    local parsed = parse(code,1)
    -- p(parsed)
    -- print(dumpParsed(parsed))
    run(parsed.main,parsed,0)
end

local fs = require("fs")
runcode(fs.readFileSync(args[1]))
