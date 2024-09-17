# Week 3 demo: simple web server

Create the directory named `demo`:

    mkdir demo
    cd demo

Create the file `hello.html` in this directory:

    <html>
        <head>
            <title>Demo demo demo!</title>
        </head>
        <body>
            <h2>Hello from webserver!</h2>
        </body>
    </html>

Start the web server in this directory:

    python3 -m http.server

Note that the web server is started on port 8000.

Request the web resource from the browser: http://localhost:8000/hello.html

URL parts:
 - `http`: protocol
 - `locahost:8000`: web server address and port
 - `hello.html`: requested resource

Note that the resource (HTML document created above) is fetched by the client from the web server
and transformed (rendered) to a human readable text. This is possible because:
 - Web client knows how to talk HTTP to the web server and retrieve documents
 - Web server understands HTTP
 - Web client understands HTML and knows how to render it

Send another request to the web server without specifying any exact resource: http://localhost:8000.

Note that if no resource is requested, web server just lists all available resources in this
directory. This list is called directory index. This behavior is common for most web servers.

Go back to the terminal where web server logs are printed. You will see something similar to:

    Serving HTTP on 0.0.0.0 port 8000 ...
    127.0.0.1 - - [04/Sep/2022 17:47:30] "GET /hello.html HTTP/1.1" 200 -
    127.0.0.1 - - [04/Sep/2022 17:49:41] "GET / HTTP/1.1" 200 -

Web server is telling about the requests it got, and how did it respond:
 - `GET` means that the client has requested some resource
 - `/hello.html` is the requested path, `/` means no resource were requested
 - `HTTP/1.1` is the protocol the client used for request
 - `200` is the server response code (means that resource was found on server and sent to client)

Web browser is not the only possible web client; there are command-line clients, clients being part
of other services etc.

Try some command line web client:

    wget --output-document=- http://localhost:8000/hello.html
    wget --output-document=- http://localhost:8000
    curl http://localhost:8000/hello.html
    curl http://localhost:8000

You may need to install cURL first, on Debian/Ubuntu/etc. run `sudo apt install curl` if the last
two commands are not working.

Note that directory listing is also a HTML page. This is created by web server automatically.

Hint: start using `wget`, `curl` or better, both. Get some practice with them. These are essential
tools and every developer, tester, devops or sysadmin must know how to use them.

HTTP is text-based protocol, and it can be easily emulated manually. You don't even need web client.
Run the telnet session and connect to the web server:

    telnet localhost 8000

You may need to install telnet first, on Debian/Ubuntu/etc. run `sudo apt install telnet` if the
command above is not working.

Request a resource from the web server:

    GET /hello.html

Press `Enter` twice to send the request to the web server.

Note that we didn't specify the protocol. Web server is smart enough to choose one automatically.

This example with telnet is purely artificial though. You'll rarely need telnet to talk to web
servers; web browsers and command line tools mentioned above (`wget` and `curl`) should cover most
of the needs.

---

You should now have the basic understanding how web clients talk to web servers using HTTP protocol.

Make sure to stop the web server (`Ctrl+C`) once done with your experiments!
