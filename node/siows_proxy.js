var io = require('socket.io').listen(8023);

var WebSocket = require('websocket-client').WebSocket;

io.sockets.on('connection', function (iosock) {
    console.log("New connection!");
    iosock.send('wait');

    var ws = new WebSocket('ws://localhost:8123');

    ws.onopen = function (event) {
      iosock.send('connected');
    };
    ws.onmessage = function (event) {
      iosock.send(event.data);
    };
    ws.onclose = function (event) {
      iosock.disconnect();
    };

    iosock.on('message', function (data) {
      ws.send(data)
    });
    iosock.on('disconnect', function () {
      ws.close();
    });
});
