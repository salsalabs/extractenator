curl -H "Content-Type: application/json" \
-H 'authToken: Dp5aFQ3HMMz6ARRYQlKGxoeOuG8X7l2N6toEx5o0i7nx31z3Vzq-Oq3DdXYYG6hzY8aFY0lnQGpInF0gIYsSRAQyIIlwYKGdw7uUU4XEyGBfCNO7MCmhS37rsOrWncnKUB0tB6HUgp-QiMcI0wxh2w' \
-X POST \
-d '{ "payload": { "count":10, "offset":0, "email": "blaise.dufrain@saltermitchell.com", "modifiedFrom": "2017-05-01T16:22:06.978Z" }}' \
https://api.salsalabs.org/api/integration/ext/v1/supporters/search

