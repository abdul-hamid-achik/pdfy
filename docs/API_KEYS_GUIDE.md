# API Keys Guide for PDFy Data Sources

This guide will help you obtain API keys for each supported data source type.

## 1. Weather API (OpenWeatherMap)

**Service**: OpenWeatherMap API  
**Free Tier**: 1,000 calls/day

### Steps to get API Key:
1. Go to [https://openweathermap.org/api](https://openweathermap.org/api)
2. Click "Sign Up" and create a free account
3. After email verification, go to [API Keys tab](https://home.openweathermap.org/api_keys)
4. Copy your default API key or create a new one
5. Set in Railway: `OPENWEATHER_API_KEY=your_key_here`

### Example API Endpoint:
```
https://api.openweathermap.org/data/2.5/weather?q={city}&appid={api_key}
```

## 2. Stock API (Alpha Vantage)

**Service**: Alpha Vantage API  
**Free Tier**: 5 API requests/minute, 100 calls/day

### Steps to get API Key:
1. Go to [https://www.alphavantage.co/support/#api-key](https://www.alphavantage.co/support/#api-key)
2. Fill out the form (takes 30 seconds)
3. You'll receive your API key instantly
4. Set in Railway: `ALPHA_VANTAGE_API_KEY=your_key_here`

### Example API Endpoint:
```
https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol={symbol}&apikey={api_key}
```

## 3. News API

**Service**: NewsAPI.org  
**Free Tier**: 1,000 requests/day (Developer plan)

### Steps to get API Key:
1. Go to [https://newsapi.org/register](https://newsapi.org/register)
2. Create a free account
3. Your API key will be displayed on the dashboard
4. Set in Railway: `NEWS_API_KEY=your_key_here`

### Example API Endpoint:
```
https://newsapi.org/v2/top-headlines?country={country}&apikey={api_key}
```

## 4. Location API (IP Geolocation)

### Option A: IPinfo.io (Recommended)
**Free Tier**: 50,000 requests/month

1. Go to [https://ipinfo.io/signup](https://ipinfo.io/signup)
2. Sign up for free account
3. Get your access token from dashboard
4. Set in Railway: `IPINFO_TOKEN=your_token_here`

### Option B: ipapi.com
**Free Tier**: 1,000 requests/month

1. Go to [https://ipapi.com/signup/free](https://ipapi.com/signup/free)
2. Create free account
3. Copy API key from dashboard
4. Set in Railway: `IPAPI_KEY=your_key_here`

### Example API Endpoints:
```
# IPinfo.io
https://ipinfo.io/{ip}?token={token}

# ipapi.com
http://api.ipapi.com/{ip}?access_key={api_key}
```

## 5. Custom API

For custom APIs, you'll need:
- API endpoint URL
- Authentication method (API key, Bearer token, etc.)
- Request format (GET/POST)
- Response format (JSON expected)

Common custom API providers:
- **Airtable**: [https://airtable.com/account](https://airtable.com/account)
- **Google Sheets**: [https://console.cloud.google.com/](https://console.cloud.google.com/)
- **Notion**: [https://www.notion.so/my-integrations](https://www.notion.so/my-integrations)

## Setting API Keys in Railway

### Method 1: Railway Dashboard
1. Go to your Railway project
2. Click on your service (pdfy-web or worker)
3. Go to "Variables" tab
4. Add each API key as an environment variable

### Method 2: Railway CLI
```bash
railway variables --set "OPENWEATHER_API_KEY=your_key_here"
railway variables --set "ALPHA_VANTAGE_API_KEY=your_key_here"
railway variables --set "NEWS_API_KEY=your_key_here"
railway variables --set "IPINFO_TOKEN=your_token_here"
```

## Best Practices

1. **Never commit API keys** to your repository
2. **Use environment variables** for all API keys
3. **Set rate limiting** in your application to avoid exceeding quotas
4. **Monitor usage** through each service's dashboard
5. **Use caching** (already implemented via DataPoint model)

## Testing API Keys

You can test if your API keys are working by running:

```ruby
# In Rails console
ds = DataSource.new(
  name: "Test Weather",
  source_type: "weather",
  api_endpoint: "https://api.openweathermap.org/data/2.5/weather",
  api_key: ENV['OPENWEATHER_API_KEY'],
  user: User.first
)

result = ds.fetch_data(city: "London")
puts result.inspect
```

## Rate Limits Summary

| Service | Free Tier Limit | Reset Period |
|---------|----------------|--------------|
| OpenWeatherMap | 1,000 calls | Daily |
| Alpha Vantage | 5 calls/min, 100/day | Per minute/Daily |
| NewsAPI | 1,000 calls | Daily |
| IPinfo.io | 50,000 calls | Monthly |
| ipapi.com | 1,000 calls | Monthly |

## Support

If you need higher limits, most services offer affordable paid plans starting at $10-50/month.