/*
 * Requires json2.js
 *
 * a backwards compatable implementation of postMessage
 * by Josh Fraser (joshfraser.com)
 * update by Bobby Hubbard - customization to support json messages
 *
 * released under the Apache 2.0 license.
 *
 * this code was adapted from Ben Alman's jQuery postMessage code found at:
 * http://benalman.com/projects/jquery-postmessage-plugin/
 *
 * other inspiration was taken from Luke Shepard's code for Facebook Connect:
 * http://github.com/facebook/connect-js/blob/master/src/core/xd.js
 *
 * the goal of this project was to make a backwards compatable version of postMessage
 * without having any dependency on jQuery or the FB Connect libraries
 *
 * my goal was to keep this as terse as possible since my own purpose was to use this
 * as part of a distributed widget where filesize could be sensative.
 *
 */

// everything is wrapped in the XD function to reduce namespace collisions
var XD = function(){

    var interval_id,
    last_hash,
    cache_bust = 1,
    attached_callback,
    window = this;

    return {
        postMessage : function(message, target_url, target) {

            // if (!target_url) {
            //     return;
            // }

            target = target || parent;  // default to parent

            if (window['postMessage']) {

                // Posting to the Gauth login form (served by spring webflow) after session timeout
                // redisplays the login form, but seems to encode every parameter unnecessarily a 2nd time.
                // Check for this and only decode if needed.
                if (target_url.indexOf("%253A%252F%252F") >= 0) {
                    target_url = decodeURIComponent(target_url);
                    console.info('postmessage.js: decoded over-encoded target_url to: [' + target_url + ']');
                }

                // the browser supports window.postMessage, so call it with a targetOrigin
                // set appropriately, based on the target_url parameter.
                // var newURL      = target_url.replace( /([^:]+:\/\/[^\/]+).*/, '$1');
                var jsonMessage = JSON.stringify(message);

                console.info('postmessage.js: newURL: [' + '*' + '], jsonMessage: [' + jsonMessage + ']');

                target['postMessage'](jsonMessage, '*');
            } else if (target_url) {
                // the browser does not support window.postMessage, so set the location
                // of the target to target_url#message. A bit ugly, but it works! A cache
                // bust parameter is added to ensure that repeat messages trigger the callback.
                target.location = target_url.replace(/#.*$/, '') + '#' + (+new Date) + (cache_bust++) + '&' + JSON.stringify(message);
            }
        },

        receiveMessage : function(callback, source_origin) {

            // browser supports window.postMessage
            if (window['postMessage']) {
                // bind the callback to the actual event associated with window.postMessage
                if (callback) {
                    attached_callback = function(e) {
                        if ((typeof source_origin === 'string' && e.origin !== source_origin)
                        || (Object.prototype.toString.call(source_origin) === "[object Function]" && source_origin(e.origin) === !1)) {
                            return !1;
                        }
                        callback(e);
                    };
                }
                if (window['addEventListener']) {
                    window[callback ? 'addEventListener' : 'removeEventListener']('message', attached_callback, !1);
                } else {
                    window[callback ? 'attachEvent' : 'detachEvent']('onmessage', attached_callback);
                }
            } else {
                // a polling loop is started & callback is called whenever the location.hash changes
                interval_id && clearInterval(interval_id);
                interval_id = null;

                if (callback) {
                    interval_id = setInterval(function(){
                        var hash = document.location.hash,
                        re = /^#?\d+&/;
                        if (hash !== last_hash && re.test(hash)) {
                            last_hash = hash;
                            callback({"data": JSON.parse(decodeURIComponent(hash.replace(re, '')))});
                        }
                    }, 100);
                }
            }
        }
    };
}();
