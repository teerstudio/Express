//
//  main.swift
//  SwiftExpress
//
//  Created by Daniel Leping on 12/16/15.
//  Copyright © 2015-2016 Daniel Leping (dileping)
//

import Foundation
import Express
import BrightFutures

let app = express()

//always enable for production
//app.views.cache = true

app.views.register(JsonView())
app.views.register(MustacheViewEngine())
app.views.register(StencilViewEngine())

app.get("/echo") { request in
    return Action.ok(request.query["call"]?.first)
}

enum NastyError : ErrorType {
    case Recoverable
    case Fatal(reason:String)
}

app.get("/error/:fatal?") { request in
    guard let fatal = request.params["fatal"] else {
        throw NastyError.Recoverable
    }
    
    throw NastyError.Fatal(reason: fatal)
}

app.errorHandler.register { (e:NastyError) in
    switch e {
    case .Recoverable:
        return Action<AnyContent>.redirect("/")
    case .Fatal(let reason):
        let content = AnyContent(str: "Unrecoverable nasty error happened. Reason: " + reason)
        return Action<AnyContent>.response(.InternalServerError, content: content)
    }
}

/// Custom page not found error handler
app.errorHandler.register { (e:ExpressError) in
    switch e {
    case .PageNotFound(let path):
        return Action<AnyContent>.render("404", context: ["path": path], status: .NotFound)
    default:
        return nil
    }
}

/// StaticAction is just a predefined configurable handler for serving static files.
/// It's important to pass exactly the same param name to it from the url pattern.
app.get("/:file+", action: StaticAction(path: "public", param:"file"))

app.get("/hello") { request in
    return Action.ok(AnyContent(str: "<h1>Hello Express!!!</h1>", contentType: "text/html"))
}

//user as an url param
app.get("/hello/:user.html") { request in
    //get user
    let user = request.params["user"]
    //if there is a user - create our context. If there is no user, context will remain nil
    let context = user.map {["user": $0]}
    //render our template named "hello"
    return Action.render("hello", context: context)
}

app.post("/api/user") { request in
    //check if JSON has arrived
    guard let json = request.body?.asJSON() else {
        return Action.ok("Invalid request")
    }
    //check if JSON object has username field
    guard let username = json["username"].string else {
        return Action.ok("Invalid request")
    }
    //compose the response as a simple dictionary
    let response =
        ["status": "ok",
        "description": "User with username '" + username + "' created succesfully"]
    
    //render disctionary as json (remember the one we've registered above?)
    return Action.render(JsonView.name, context: response)
}

//:param - this is how you define a part of URL you want to receive through request object
app.get("/echo/:param") { request in
    //here you get the param from request: request.params["param"]
    return Action.ok(request.params["param"])
}

func factorial(n: Double) -> Double {
    return n == 0 ? 1 : n * factorial(n - 1)
}

func calcFactorial(num:Double) -> Future<Double, AnyError> {
    return future {
        return factorial(num)
    }
}

// (request -> Future<Action<AnyContent>, AnyError> in) - this is required to tell swift you want to return a Future
// hopefully inference in swift will get better eventually and just "request in" will be enough
app.get("/factorial/:num(\\d+)") { request -> Future<Action<AnyContent>, AnyError> in
    // get the number from the url
    let num = request.params["num"].flatMap{Double($0)}.getOrElse(0)
    
    // get the factorial Future. Returns immediately - non-blocking
    let factorial = calcFactorial(num)
    
    //map the result of future to Express Action
    let future = factorial.map { fac in
        Action.ok(String(fac))
    }
    
    //return the future
    return future
}

func testItems(request:Request<AnyContent>) throws -> [String: Any] {
    let newItems = request.query.map { (k, v) in
        (k, v.first!)
    }
    let items = ["sky": "blue", "fire": "red", "grass": "green"] ++ newItems
    
    let viewItems = items.map { (k, v) in
        ["name": k, "color": v]
    }
    
    if let reason = request.query["throw"]?.first {
        throw NastyError.Fatal(reason: reason)
    }
    
    return ["test": "ok", "items": viewItems]
}

app.get("/render.html") { request in
    let items = try testItems(request)
    return Action.render("test", context: items)
}

//TODO: make a list of pages
app.get("/") { request in
    /*let examples = [
        ["title": "Hello Express", "link": "/hello"],
        ["title": "Echo", "link": "/echo?call=hello"],
        ["title": "Echo with param", "link": "/echo/hello"],
        ["title": "Error recoverable (will redirect back)", "link": "/error"],
        ["title": "Error fatal", "link": "/error/thebigbanghappened"],
        ["title": "Custom 404", "link": "/thisfiledoesnotexist"],
        ["title": "Hello [username]. You can put your name instead", "link": "/hello/username.html"],
        ///api/user - implement JSON post form
        ["title": "Asynchronous factorial", "link": "/factorial/100"],
        ["title": "Render", "link": "/render.html?sun=yellow&clouds=lightgray"],
        ["title": "Redirect", "link": "/test/redirect"],
        ["title": "Merged query (form url encoded and query string)", "link": "/merged/query?some=param&another=param2"],
    ]
    
    return Action.render("index", context: ["examples": examples])*/
    return Action.redirect("/index.html")
}

app.get("/test/redirect") { request in
    return future {
        let to = request.query["to"].flatMap{$0.first}.getOrElse("../render.html")
        return Action.redirect(to)
    }
}

app.all("/merged/query") { request in
    Action.render(JsonView.name, context: request.mergedQuery())
}

app.listen(9999).onSuccess { server in
    print("Express was successfully launched on port", server.port)
}

app.run()
