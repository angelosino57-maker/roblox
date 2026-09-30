-- Token-Bucket pro Key (meist der Player).
local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(maxPerSecond: number, clock: (() -> number)?)
	return setmetatable({
		max = maxPerSecond,
		clock = clock or os.clock,
		buckets = {},
	}, RateLimiter)
end

function RateLimiter:allow(key): boolean
	local now = self.clock()
	local bucket = self.buckets[key]
	if bucket == nil then
		bucket = { tokens = self.max, at = now }
		self.buckets[key] = bucket
	end
	bucket.tokens = math.min(self.max, bucket.tokens + (now - bucket.at) * self.max)
	bucket.at = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter:forget(key)
	self.buckets[key] = nil
end

return RateLimiter
