local SynthesisSystem = {}
SynthesisSystem.__index = SynthesisSystem

-- 初始化合成系统
function SynthesisSystem.New(externalTable)
    local self = setmetatable({}, SynthesisSystem)
    self.internalRecipes = {}  -- 内部合成表（用于快速查询）
    self.recipeMetadata = {}   -- 合成配方元数据（包含输出数量等信息）
    self:convertExternalTable(externalTable)
    return self
end

-- 核心转表功能：将外部配方表转换为内部查询结构
-- 支持两种外部表格式：字符串格式和结构化格式
function SynthesisSystem:convertExternalTable(externalTable)
    for _, recipe in ipairs(externalTable) do
        local inputItems, outputItem,removeItems
        -- 处理字符串格式配方（如："itemA:1+itemB:2=itemC:1"）
        if type(recipe) == "string" then
            local inputStr, outputStr = recipe:match("^(.+)=(.+)$")
            if not inputStr or not outputStr then
                error("Invalid recipe format: " .. recipe)
            end
            -- 解析输出项
            local outputId, outputCount = outputStr:match("^([^:]+):?(%d*)$")
            outputItem = {
                id = outputId,
                count = outputCount and tonumber(outputCount) or 0
            }
            -- 解析输入项
            inputItems = {}
            for itemStr in inputStr:gmatch("[^+]+") do
                local itemId, itemCount = itemStr:match("^([^:]+):?(%d*)$")
                table.insert(inputItems, {
                    id = itemId,
                    count = itemCount and tonumber(itemCount) or 0
                })
            end
        -- 处理结构化格式配方
        elseif type(recipe) == "table" then
            inputItems = recipe.input
            outputItem = {
                id = recipe.output,
                count = recipe.count or 1
            }
        -- 处理表格类数据
        elseif type(recipe) == "userdata" then
            local outputStr = recipe.TargetItem   
            local outputId, outputCount = outputStr:match("^([^:]+):?(%d*)$")
            outputItem = {
                id = outputId,
                count = outputCount and tonumber(outputCount) or 0
            }        
            inputItems = {}
            for k, itemStr in pairs(recipe.RequiredItems) do
                local itemId, itemCount = itemStr:match("^([^:]+):?(%d*)$")
                table.insert(inputItems, {
                    id = itemId,
                    count = itemCount and tonumber(itemCount) or 0
                })
            end
            removeItems = {}
            for k, itemStr in pairs(recipe.RemoveItems) do
                local itemId, itemCount = itemStr:match("^([^:]+):?(%d*)$")
                table.insert(removeItems, {
                    id = itemId,
                    count = itemCount and tonumber(itemCount) or 0
                })
            end
             
        end
        -- 生成排序后的输入key（确保无序输入也能匹配）
        table.sort(inputItems, function(a, b) return a.id < b.id end)
        local keyParts = {}
        for _, item in ipairs(inputItems) do
            table.insert(keyParts, string.format("%s:%d", item.id, item.count))
        end
        local recipeKey = table.concat(keyParts, ",")

        -- 存储到内部结构
        if outputItem and inputItems then
            self.internalRecipes[recipeKey] = outputItem.id
            self.recipeMetadata[recipeKey] = {
                outputCount = outputItem.count,
                inputItems = inputItems,
                removeItems = removeItems
            }
        else
            ugcprint("Error [LJH] SynthesisSystem:convertExternalTable recipe not Vaild")    
        end        
    end
    UGCLog.HLog("SynthesisSystem", "Loaded recipe: ",self.internalRecipes,self.recipeMetadata)
end


---@param inputItems  {{id = "itemA", count = 1}, {id = "itemB", count = 2}, ...}
function SynthesisSystem:Synthesize(inputItems)
    -- 排序输入项以匹配内部key
    local sortedInput = {}
    for _, item in ipairs(inputItems) do
        table.insert(sortedInput, {id = item.id, count = item.count or 1})
    end
    table.sort(sortedInput, function(a, b) return a.id < b.id end)

    -- 1. 尝试标准的精确匹配查询（保持向后兼容性）
    local keyParts = {}
    for _, item in ipairs(sortedInput) do
        table.insert(keyParts, string.format("%s:%d", item.id, item.count))
    end
    local queryKey = table.concat(keyParts, ",")

    -- 查询合成结果
    local outputId = self.internalRecipes[queryKey]
    local matchedKey = queryKey
    
    -- 2. 如果标准查询失败，执行数量检查逻辑
    if not outputId then
        -- 创建输入物品的映射表，方便快速查找
        local inputMap = {}
        for _, item in ipairs(sortedInput) do
            inputMap[item.id] = item.count
        end
        
        -- 遍历所有配方进行检查
        for key, resultId in pairs(self.internalRecipes) do
            local recipeInputs = self.recipeMetadata[key].inputItems
            local match = true
            
            -- 检查配方所需的每个物品
            for _, recipeItem in ipairs(recipeInputs) do
                -- 检查是否有对应的物品且数量足够
                if not inputMap[recipeItem.id] or inputMap[recipeItem.id] < recipeItem.count then
                    match = false
                    break
                end
            end
            
            -- 如果所有必要物品都存在且数量足够
            if match then
                outputId = resultId
                matchedKey = key
                break
            end
        end
    end

    if outputId then
        return {
            key = outputId,
            count = self.recipeMetadata[matchedKey].outputCount,
            metadata = self.recipeMetadata[matchedKey]
        }
    end
    return nil  -- 无匹配配方
end
-- 反向查询：获取物品的所有合成配方
function SynthesisSystem:GetRecipesForItem(itemId)
    local recipes = {}
    for key, outputId in pairs(self.internalRecipes) do
        if outputId == itemId then
            table.insert(recipes, {
                input = self.recipeMetadata[key].inputItems,
                outputCount = self.recipeMetadata[key].outputCount
            })
        end
    end
    return recipes
end


-- 技能合成 把Count 改成Level
function SynthesisSystem:SynthesizeSkill(skills)
    -- 转换技能列表为合成系统所需的输入格式
    local inputItems = {}
    for _, skill in ipairs(skills) do
        table.insert(inputItems, {
            id = tostring(skill.Key),   -- 技能ID转为字符串匹配内部格式
            count = skill.Level        -- 技能等级作为数量参数
        })
    end
    
    -- 调用基础合成方法
    local result = self:Synthesize(inputItems)
    --UGCLog.HLog("SynthesisSystem:SynthesizeSkill",inputItems,result)
    if result then
        local tRemoveItems = {}
        for k, v in pairs(result.metadata.removeItems) do
            table.insert(tRemoveItems,{SkillID = tonumber(v.id),Level = v.count})
        end
        -- 返回数值型技能ID和等级
        return tonumber(result.key), result.count, tRemoveItems
    end
    -- for k, v in pairs(inputItems) do
    --     ugcprint("Error [LJH] SynthesisSystem:SynthesizeSkill result not Vaild "..tostring(v.id).." "..tostring(v.count))    
    -- end    
    return nil, nil, {}  -- 无匹配配方时返回nil
end

return SynthesisSystem