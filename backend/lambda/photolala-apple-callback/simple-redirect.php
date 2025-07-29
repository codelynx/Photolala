<?php
/**
 * Simple PHP redirect for Apple Sign-In callback
 * Place this at: https://photolala.electricwoods.com/api/auth/apple/callback/index.php
 */

// Forward the POST request to API Gateway
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $api_gateway_url = 'https://kbzojywsa5.execute-api.us-east-1.amazonaws.com/prod/auth/apple/callback';
    
    // Get POST data
    $post_data = http_build_query($_POST);
    
    // Set up cURL
    $ch = curl_init($api_gateway_url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $post_data);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, array(
        'Content-Type: application/x-www-form-urlencoded',
        'Content-Length: ' . strlen($post_data)
    ));
    
    // Execute request
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    // Output the response (which is HTML with redirect)
    http_response_code($http_code);
    echo $response;
} else {
    // For GET requests (testing)
    header('Location: https://kbzojywsa5.execute-api.us-east-1.amazonaws.com/prod/auth/apple/callback?' . $_SERVER['QUERY_STRING']);
    exit();
}
?>