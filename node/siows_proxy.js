var io = require('socket.io').listen(8023);

var WebSocket = require('websocket-client').WebSocket;

io.sockets.on('connection', function (iosock) {
    var prequeue = [];
    var established = false;

    console.log("New connection!");

    var ws = new WebSocket('ws://localhost:8123');

    ws.onopen = function (event) {
      try {
        console.log("Tunnel established");

        established = true;
        prequeue.forEach(function (msg) {
          console.log("P>> "+ msg);
          ws.send(msg);
        });
        prequeue = null;
      } catch (err) {
        console.log("ERROR: "+err);
      }
    };
    ws.onmessage = function (event) {
      try {
        console.log("<< " + event.data);
        iosock.send(event.data);
      } catch (err) {
        console.log("ERROR: "+err);
      }
    };
    ws.onclose = function (event) {
      try {
        iosock.disconnect();
      } catch (err) {
        console.log("ERROR: "+err);
      }
    };
    ws.onerror = function (event) {
      try {
        iosock.disconnect();
      } catch (err) {
        console.log("ERROR: "+err);
      }
    };

    iosock.on('message', function (data) {
      try {
        if (established) {
          console.log(">> " + data);
          ws.send(data);
        } else {
          prequeue.push(data);
        }
      } catch (err) {
        console.log("ERROR: "+err);
      }
    });
    iosock.on('disconnect', function () {
      try {
        ws.close();
      } catch (err) {
        console.log("ERROR: "+err);
      }
    });
    iosock.on('error', function () {
      try {
        ws.close();
      } catch (err) {
        console.log("ERROR: "+err);
      }
    });
  });
