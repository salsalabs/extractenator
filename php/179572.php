<?php
    // Uses Composer.
    require 'vendor/autoload.php';
    use GuzzleHttp\Client;
    
    $headers = [
        'authToken' => 'Dp5aFQ3HMMz6ARRYQlKGxoeOuG8X7l2N6toEx5o0i7nx31z3Vzq-Oq3DdXYYG6hzY8aFY0lnQGpInF0gIYsSRAQyIIlwYKGdw7uUU4XEyGBfCNO7MCmhS37rsOrWncnKUB0tB6HUgp-QiMcI0wxh2w',
        'Content-Type' => 'application/json'
    ];
    $payload = [
    	'count' => 1,
    	'offset' => 0,
    	'email' => 'bdufrain89@gmail.com',
    	'modifiedFrom' => '2017-05-01T00:00:00'
    ];
    $method = 'POST';
    $uri = 'https://api.salsalabs.org';
    $command = '/api/integration/ext/v1/supporters/search';
    $client = new GuzzleHttp\Client([
        'base_uri' => $uri,
        'headers'  => $headers
    ]);
    try {
        $response = $client->request($method, $command, [
            'json'     => $payload
        ]);
        
        echo $response->getStatusCode();      // >>> 200
        echo $response->getReasonPhrase();    // >>> OK
        echo $response->getProtocol();        // >>> HTTP
        echo $response->getProtocolVersion(); // >>> 1.1
    
        $data = json_decode($response -> getBody());
    
        echo gettype($data);
        var_dump($data);
    } catch (Exception $e) {
    echo 'Caught exception: ',  $e->getMessage(), "\n";
    // var_dump($e);
}

?>
