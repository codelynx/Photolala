exports.handler = async (event, context) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    console.log('Context:', JSON.stringify(context, null, 2));
    
    try {
        // Handle Apple's URL validation (GET request)
        const method = event.requestContext?.http?.method || event.requestContext?.httpMethod || event.httpMethod || 'UNKNOWN';
        
        if (method === 'GET' && !event.queryStringParameters) {
            // Apple might be checking if the URL exists
            return {
                statusCode: 200,
                headers: {
                    'Content-Type': 'text/html',
                    'Cache-Control': 'no-cache'
                },
                body: '<!DOCTYPE html><html><head><title>Apple Sign-In Callback</title></head><body><h1>Apple Sign-In Callback Endpoint</h1><p>This endpoint handles Apple Sign-In callbacks.</p></body></html>'
            };
        }
        // Handle both GET and POST methods
        let params = {};
        
        if (method === 'POST' && event.body) {
            // Check if body is base64 encoded
            let bodyStr = event.body;
            if (event.isBase64Encoded) {
                bodyStr = Buffer.from(event.body, 'base64').toString('utf-8');
            }
            
            // Parse form data from Apple's POST
            const formData = new URLSearchParams(bodyStr);
            for (const [key, value] of formData) {
                params[key] = value;
            }
        } else if (event.queryStringParameters) {
            // Handle GET request (for testing)
            params = event.queryStringParameters;
        }
        
        console.log('Extracted params:', params);
        
        // Build deep link with parameters
        const queryString = Object.keys(params)
            .map(key => `${encodeURIComponent(key)}=${encodeURIComponent(params[key])}`)
            .join('&');
            
        const deepLink = `photolala://auth/apple${queryString ? '?' + queryString : ''}`;
        console.log('Deep link:', deepLink);
        
        // Return HTML that handles the redirect
        const html = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Redirecting to Photolala...</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background-color: #f5f5f7;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: white;
            border-radius: 12px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            max-width: 400px;
        }
        h1 {
            font-size: 24px;
            color: #1d1d1f;
            margin-bottom: 16px;
        }
        p {
            color: #86868b;
            margin-bottom: 24px;
        }
        .spinner {
            width: 48px;
            height: 48px;
            border: 3px solid #e8e8ed;
            border-top: 3px solid #0071e3;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto 24px;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .button {
            display: inline-block;
            padding: 12px 24px;
            background-color: #0071e3;
            color: white;
            text-decoration: none;
            border-radius: 6px;
            font-weight: 500;
        }
        .button:hover {
            background-color: #0077ed;
        }
        .debug {
            margin-top: 40px;
            padding: 20px;
            background: #f5f5f7;
            border-radius: 8px;
            text-align: left;
            font-family: monospace;
            font-size: 12px;
            color: #666;
            max-height: 200px;
            overflow-y: auto;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="spinner"></div>
        <h1>Completing Sign In...</h1>
        <p>Redirecting you back to Photolala</p>
        <a href="${deepLink}" class="button">Open Photolala</a>
        
        <div style="margin-top: 20px;">
            <p style="font-size: 14px; color: #666;">Not redirecting automatically?</p>
            <a href="intent://auth/apple${queryString ? '?' + queryString : ''}#Intent;scheme=photolala;package=com.electricwoods.photolala;end" 
               style="color: #0071e3; text-decoration: underline;">
                Try Android Intent Link
            </a>
        </div>
        
        <div class="debug">
            <strong>Debug Info:</strong><br>
            Method: ${method}<br>
            Deep Link: ${deepLink}<br>
            Params: ${JSON.stringify(params, null, 2)}
        </div>
    </div>
    
    <script>
        console.log('Attempting to redirect to:', '${deepLink}');
        
        // Method 1: Direct location change
        window.location.href = '${deepLink}';
        
        // Method 2: Location replace (no back button)
        setTimeout(function() {
            window.location.replace('${deepLink}');
        }, 500);
        
        // Method 3: Android Intent URL (most reliable for Android)
        setTimeout(function() {
            const intentUrl = 'intent://auth/apple${queryString ? '?' + queryString : ''}#Intent;scheme=photolala;package=com.electricwoods.photolala;end';
            console.log('Trying intent URL:', intentUrl);
            window.location.href = intentUrl;
        }, 1000);
        
        // Method 4: Create and click a link
        setTimeout(function() {
            const link = document.createElement('a');
            link.href = '${deepLink}';
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
        }, 1500);
        
        // Log for debugging
        window.addEventListener('error', function(e) {
            console.error('Redirect error:', e);
        });
    </script>
</body>
</html>`;
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'text/html',
                'Cache-Control': 'no-cache, no-store, must-revalidate'
            },
            body: html
        };
        
    } catch (error) {
        console.error('Error:', error);
        
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'text/html'
            },
            body: `
<!DOCTYPE html>
<html>
<head>
    <title>Error</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: -apple-system, sans-serif; padding: 20px;">
    <h1>Authentication Error</h1>
    <p>Something went wrong. Please try again.</p>
    <pre style="background: #f5f5f5; padding: 10px; overflow: auto;">${error.message}</pre>
</body>
</html>`
        };
    }
};