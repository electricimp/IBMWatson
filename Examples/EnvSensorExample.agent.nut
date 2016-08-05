#require "bullwinkle.class.nut:2.3.0"
#require "promise.class.nut:3.0.0"
#require "IBMWatson.class.nut:1.0.0"

class Application {
    static API_KEY = "a-9guj6a-zbzveplzcn";
    static AUTH_TOKEN = "YJx)n8@u2*F@Yh(gUK";
    static ORG_ID = "9guj6a";

    static DEVICE_TYPE_ID = "EnvTail";
    static DEVICE_TYPE_DESCRIPTION = "Environmental Sensor Tail";
    static DEVICE_MANUFACTURER = "Electric Imp";
    static EVENT_ID = "EnvironmentalReadings"

    _watson = null;
    _deviceID = null;
    _deviceInfo = null;

    _bull = null;

    constructor() {
        initializeClasses();
        openListeners();

        local series = [createDevType(), getDevInfo()];
        Promise.all(series)
            .then(function(status) {
                server.log(http.jsonencode(status));
                // create device
                createDev();
            }.bindenv(this))
    }

    function createDevType() {
        return Promise(function(resolve, reject) {
            _watson.getDeviceType(DEVICE_TYPE_ID, function(err, res) {
                switch (err) {
                    case _watson.MISSING_RESOURCE_ERROR:
                        // dev type doesn't exist yet create it
                        local typeInfo = {"id" : DEVICE_TYPE_ID, "description" : DEVICE_TYPE_DESCRIPTION};
                        _watson.addDeviceType(typeInfo, function(error, response) {
                            if (error != null) return reject(error);
                            return resolve("Dev type created");
                        }.bindenv(this));
                        break;
                    case null:
                        // dev type exists, good to use for this device
                        return resolve("Dev type exists");
                        break;
                    default:
                        // we encountered an error
                        return reject(err);
                }
            }.bindenv(this));
        }.bindenv(this));
    }

    function getDevInfo() {
        return Promise(function(resolve, reject) {
            imp.wakeup(0.5, function() {
                _bull.send("devInfo")
                    .onReply(function(message) {
                        setDeviceInfo(message.data);
                        resolve("Dev info stored");
                    }.bindenv(this)) // end onReply
                    .onFail(function(err, message, retry) {
                        setBasicDevInfo();
                        resolve(err);
                    }.bindenv(this)) // end onFail
            }.bindenv(this)) // end wakeup
        }.bindenv(this)); // end promise
    }

    function initializeClasses() {
        _bull = Bullwinkle();
        _watson = IBMWatson(API_KEY, AUTH_TOKEN, ORG_ID);
    }

    function openListeners() {
        _bull.on("reading", sendReadingToWatson.bindenv(this));
        _bull.on("sendDevInfo", createDev.bindenv(this));
    }

    function setDeviceInfo(info) {
        _deviceID = info.devID.tostring();
        _deviceInfo = { "manufacturer" : DEVICE_MANUFACTURER,
                        "descriptiveLocation" : info.location,
                        "fwVersion" : info.swVersion,
                        "model" : info.mac };
    }

    function setBasicDevInfo() {
        _deviceID = imp.configparams.deviceid.tostring();
        _deviceInfo = {"manufacturer" : DEVICE_MANUFACTURER};
    }

    function sendReadingToWatson(message, reply) {
        local reading = message.data;
        server.log(http.jsonencode(reading));
        local data = { "d": reading,
                       "ts": _watson.formatTimestamp() };
        // server.log(typeof _deviceID)
        _watson.postData(DEVICE_TYPE_ID, _deviceID, EVENT_ID, data, function(err, res) {
            if(err) server.error(err);
            if(res.statuscode == 200) server.log("reading uploaded")
        }.bindenv(this));
    }

    function createDev() {
        _watson.getDevice(DEVICE_TYPE_ID, _deviceID, function(err, res) {
            switch (err) {
                case _watson.MISSING_RESOURCE_ERROR:
                    // dev doesn't exist yet create it
                    local info = {"deviceId": _deviceID,  "deviceInfo" : _deviceInfo};
                    _watson.addDevice(DEVICE_TYPE_ID, info, function(error, response) {
                        if (error != null) {
                            server.error(error);
                            return;
                        }
                        server.log("Dev created");
                    }.bindenv(this));
                    break;
                case null:
                    // dev exists, update
                    _watson.updateDevice(DEVICE_TYPE_ID, _deviceID, {"deviceInfo" : _deviceInfo}, function(error, response) {
                        if (error != null) {
                            server.error(error);
                            return;
                        }
                        server.log("Dev updated");
                    }.bindenv(this));
                    break;
                default:
                    // we encountered an error
                    server.error(err);
            }
        }.bindenv(this));
    }
}

app <- Application();