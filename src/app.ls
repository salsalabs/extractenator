require! {
    './handlers/extractenator': { Extractenator9000 }
}

# Application starts here.
(err) <- new Extractenator9000! .run
console.error err, "on", @org.uri if err?
process.exit 0
