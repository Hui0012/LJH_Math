-- 2D柏林噪声算法实现
local PerlinNoise2D = {}

-- 伪随机梯度向量表
PerlinNoise2D.gradients = {
    {1, 1}, {-1, 1}, {1, -1}, {-1, -1},
    {1, 0}, {-1, 0}, {0, 1}, {0, -1}
}

-- 置换表（伪随机数）
PerlinNoise2D.perm = {}

-- 初始化置换表
function PerlinNoise2D:init(seed)
    seed = seed or os.time()
    math.randomseed(seed)
    
    -- 填充置换表
    for i = 0, 255 do
        self.perm[i] = math.random(0, 255)
    end
    
    -- 复制置换表以避免索引越界
    for i = 256, 511 do
        self.perm[i] = self.perm[i % 256]
    end
end

-- 平滑插值函数
local function fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

-- 线性插值函数
local function lerp(a, b, t)
    return a + t * (b - a)
end

-- 获取梯度向量
local function grad(hash, x, y)
    -- 根据哈希值选择一个梯度向量
    local g = PerlinNoise2D.gradients[(hash % #PerlinNoise2D.gradients) + 1]
    -- 点积计算
    return x * g[1] + y * g[2]
end
  
-- 生成2D柏林噪声  -- 两个需求 1. 一个是传入相同X,Y  得到相同的值 2. 这个值应该由所在单元格的四个角的值进行插值得到
function PerlinNoise2D:noise(x, y)
    -- 确定单位正方形的左上角坐标
    local xi = math.floor(x) % 256
    local yi = math.floor(y) % 256
    
    -- 计算相对于正方形的坐标
    local xf = x - math.floor(x)
    local yf = y - math.floor(y)
    
    -- 计算平滑因子
    local u = fade(xf)
    local v = fade(yf)
    
    -- 获取四个角的哈希值 (可以理解为用 用相同 x,y  返回一个相同的值，而且这个值不用计算 就是随机的)
    local aa = self.perm[xi] + yi -- （x, y）
    local ab = self.perm[xi + 1] + yi -- (x + 1, y)
    local ba = self.perm[xi] + yi + 1 -- (x, y + 1)
    local bb = self.perm[xi + 1] + yi + 1 -- (x + 1, y + 1)
    
    -- 计算四个角的贡献
    local x1 = lerp(grad(self.perm[aa], xf, yf), grad(self.perm[ab], xf - 1, yf), u)
    local x2 = lerp(grad(self.perm[ba], xf, yf - 1), grad(self.perm[bb], xf - 1, yf - 1), u)
    
    -- 最终插值结果
    return lerp(x1, x2, v)
end

-- 生成带多个八度的柏林噪声（更自然的效果）
function PerlinNoise2D:octaveNoise(x, y, octaves, persistence)
    local total = 0
    local frequency = 1
    local amplitude = 1
    local maxValue = 0  -- 用于归一化结果
    
    for i = 1, octaves do
        total = total + self:noise(x * frequency, y * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end
    
    -- 归一化到[-1, 1]范围
    return total / maxValue
end

-- 生成噪声图数据
function PerlinNoise2D:generateNoiseMap(width, height, scale, octaves, persistence)
    local noiseMap = {}
    for y = 1, height do
        noiseMap[y] = {}
        for x = 1, width do
            local nx = x / width * scale
            local ny = y / height * scale
            -- 将噪声值映射到[0, 1]范围
            noiseMap[y][x] = (PerlinNoise2D:octaveNoise(nx, ny, octaves, persistence) + 1) / 2
        end
    end
    return noiseMap
end


-- 初始化模块
PerlinNoise2D:init()

return PerlinNoise2D