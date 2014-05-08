PORT = 80
ONLY_LOCAL = false
BASEDIR = ".." // __dirname
CACHE = {
	"image": 86400 // 3600s = 1h
}
IP = "unknown"

require('colors');
http = require('http');
app = http.createServer(handler);
//io = require('./socket.io.fixed.js').listen(app);
socket = require('socket.io'); io = socket.listen(app);
fs = require('fs');
mime = require('mime');