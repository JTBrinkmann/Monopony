var util = require('util')
require('colors')

// by Mozilla from https://developer.mozilla.org/en-US/docs/JavaScript/Reference/Global_Objects/Array/isArray
if(!Array.isArray) {
	Array.isArray = function (vArg) {
		return Object.prototype.toString.call(vArg) === "[object Array]";
	};
}


/* Author: Sephr
from: http://snipplr.com/view/12492/getclass/
*/
function getClass(obj, forceConstructor) {
	if ( typeof obj == "undefined" ) return "undefined";
	if ( obj === null ) return "null";
	if ( forceConstructor == true && obj.hasOwnProperty("constructor") ) delete obj.constructor; // reset constructor
	if ( forceConstructor != false && !obj.hasOwnProperty("constructor") ) return getFunctionName(obj.constructor);
	return Object.prototype.toString.call(obj)
		.match(/^\[object\s(.*)\]$/)[1];
}
 
function getFunctionName(func) {
	if ( typeof func == "function" || typeof func == "object" )
	var fName = (""+func).match(
		/^function\s*([\w\$]*)\s*\(/
	); if ( fName !== null ) return fName[1];
}


/* Functions to be used within the CLI */
Object.defineProperty(Object.prototype, "define", {
	enumerable: false,
	writable: true,
	configurable: true,
	value: function define(/*[forceRedefine], [{prop1: val1, prop2: val2, ...} | property, value]*/) {
		var forceRedefine = +(typeof arguments[0]=="boolean");
		var properties = arguments[forceRedefine];
		if(typeof properties == "string")
			(properties = {}, properties[arguments[forceRedefine]]=arguments[1+forceRedefine]);
		//var proto = this.prototype || this;
		var self=this;
		forceRedefine = arguments[0]==true;
		for(var fn in properties) {
			fn.split(",").forEach(function(fn2){
				var newFn = properties[fn];
				if(!newFn.name && typeof properties[fn] == "function")
					newFn.name = fn2;
				if(self.hasOwnProperty(fn2))
					if(!forceRedefine)
						return console.warn("cannot redifine property", self, fn2);
				if(self[fn2] !== newFn)
					Object.defineProperty(self, fn2, {
						enumerable: false,
						writable: true,
						configurable: true,
						value: newFn
					});
			})
		}
	}
});


// Object.keys
Object.prototype.define("keys", function(){return Object.keys(this).join(",\n")})
global.require = require
/**/


global.$0 = null
console.eval = function (code) {
	if (console.eval.pagination) {
		if (code.replace(/\r?\n$/, "") == "q")
			console.eval.pagination = null
		else {
			console.log(console.eval.pagination.res.slice(console.eval.maxLines*console.eval.pagination.i, console.eval.maxLines*console.eval.pagination.i+console.eval.maxLines).join("\n"))
			if (++console.eval.pagination.i < console.eval.pagination.pages)
				console.log( "[page ".green+(console.eval.pagination.i+"").red+"/".green+(console.eval.pagination.pages+"").red+" press Enter to view next page, type q to stop pagination]".green )
			else {
				console.log( "[page ".green.bold+(console.eval.pagination.i+"").red+"/".green.bold+(console.eval.pagination.pages+"").red+"]".green.bold)
				console.eval.pagination = null
			}
			return
		}
	} else if (code[code.length-3]=="\t"){
		console.eval.code=console.eval.code+code.substr(0, code.length-2)+"\n";
	} else {
		try{
			//with(console) with(Object) with(Math)
				$0 = global.$0 = global.eval(console.eval.code+code)
			var res = util.format($0)
			var res_lines = res.split("\n")
			
//			var res2=res.replace(/[^\n]{100}/g, function(a){return a+"\n"}) // manually adding a linebreak after 100 chars per line
			var type = typeof $0
			var type2 = "["+getClass($0)
			if (type == "function") {
				if($0.toString != Function.prototype.toString)
					type2 += "*"
				type2 += "]\n"
				res = $0+""
			} else if (type == "object" && $0 !== null) {
				if ($0.toString != Object.prototype.toString && !Array.isArray($0))
					type2 += "*"
				type2 += "]\n"
			} else
				type2 += "] "
			
			if (res_lines.length > console.eval.maxLines) { // paginate if the result is larger then 80 lines (ignoring auto-linebreaks due to long lines)
				console.log("<".green, type2.grey); //.replace(new RegExp(String.fromCharCode(9)+"+", "g"), "\n")))
				console.eval.pagination = {
					 pages: Math.ceil(res_lines.length/console.eval.maxLines)
					,res: res_lines
					,i: 0
				}
				console.eval("")
			} else
				console.log("<".green, type2.grey, res); //.replace(new RegExp(String.fromCharCode(9)+"+", "g"), "\n")))
			
		} catch(err) {
			if (err.toString()=="SyntaxError: Unexpected end of input")
				console.eval.code=console.eval.code+code;
			else
				console.error((console.err=err).stack.replace(this.baseStack, ""), "\n")
		}
		console.eval.code="";
	}
	process.stdout.writable && process.stdout.write("> ".cyan.bold)
}
console.eval.code="";
console.eval.maxLines=47;

process.stdin.resume();
process.stdin.setEncoding("utf8");
process.stdin.on("data", console.eval)
process.stdout.writable && process.stdout.write("> ".cyan.bold)