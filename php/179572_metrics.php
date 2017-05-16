<?php
    // Uses Composer.
    require 'vendor/autoload.php';
    use GuzzleHttp\Client;
    
    $headers = [
            'authToken' => 'Dp5aFQ3HMMz6ARRYQlKGxoeOuG8X7l2N6toEx5o0i7nx31z3Vzq-Oq3DdXYYG6hzY8aFY0lnQGpInF0gIYsSRAQyIIlwYKGdw7uUU4XEyGBfCNO7MCmhS37rsOrWncnKUB0tB6HUgp-QiMcI0wxh2w',
            'Content-Type' => 'application/json'
    ];
    $method = 'GET';
    $uri = 'https://api.salsalabs.org';
    $command = '/api/integration/ext/v1/metrics';
    $client = new GuzzleHttp\Client([
        'base_uri' => $uri,
        'headers'  => $headers
    ]);
    $response = $client->request($method, $command);

    // not valid, substituting standard JSON parse
    //$data = $response->json();
    $data = json_decode($response -> getBody());

    echo gettype($data);
    var_dump($data);
?>
