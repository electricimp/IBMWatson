#require "bullwinkle.class.nut:2.3.0"
#require "promise.class.nut:3.0.0"
#require "IBMWatson.class.nut:1.0.0"

/***************************************************************************************
 * Application Class:
 *      Initializes Watson and Bullwinkle classes
 *      Creates/Updates Device Type & Device on IBM Watson platform
 *      Listen for sensor readings & publishes them to IBM Watson
 **************************************************************************************/
class Application {
    // Watson Device Information
    static DEVICE_TYPE_ID = "EnvTail";
    static DEVICE_TYPE_DESCRIPTION = "Environmental Sensor Tail";
    static DEVICE_MANUFACTURER = "Electric Imp";
    static EVENT_ID = "EnvironmentalReadings"

    _watson = null;
    _deviceID = null;
    _deviceInfo = null;
    _meta = null;
    _bull = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      apiKey: string - Watson API Key
     *      authToken: string - Watson Auth Token
     *      orgID: string - Watson organization ID
     **************************************************************************************/
    constructor(apiKey, authToken, orgID) {
        initializeClasses(apiKey, authToken, orgID);
        openListeners();
        _meta = {};
        _deviceInfo = {};

        // Create/update Watson Platform with device type for this device
        // Get device information from device
        // Then create/update the device on Watson platform or log error
        local series = [createDevType(), getDevInfo()];
        Promise.all(series)
            .then(function(status) {
                    server.log(http.jsonencode(status));
                    // create device
                    createDev();
                }.bindenv(this),
                function(rejected) {
                    server.error(rejected);
                }.bindenv(this));
    }

    /***************************************************************************************
     * createDevType
     * Returns: Promise that resolves when device type is
                        successfully created/updated, or rejects with an error
     * Parameters: none
     **************************************************************************************/
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

    /***************************************************************************************
     * getDevInfo
     * Returns: Promise that resolves when device sends info or when basic
                        device info is set by the agent (if device not available);
     * Parameters: none
     **************************************************************************************/
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

    /***************************************************************************************
     * initializeClasses
     * Returns: this
     * Parameters:
     *      apiKey: string - Watson API Key
     *      authToken: string - Watson Auth Token
     *      orgID: string - Watson organization ID
     **************************************************************************************/
    function initializeClasses(apiKey, authToken, orgID) {
        _bull = Bullwinkle();
        _watson = IBMWatson(apiKey, authToken, orgID);
        return this;
    }

    /***************************************************************************************
     * openListeners
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function openListeners() {
        _bull.on("reading", _sendReadingHandler.bindenv(this));
        _bull.on("updateDevInfo", _updateDevInfoHandler.bindenv(this));
        return this
    }

    /***************************************************************************************
     * setDeviceInfo
     * Returns: this
     * Parameters:
     *      info: table - table with device information
     **************************************************************************************/
    function setDeviceInfo(info) {
        _deviceID = info.devID.tostring();
        _deviceInfo = { "manufacturer" : DEVICE_MANUFACTURER,
                        "descriptiveLocation" : info.location,
                        "fwVersion" : info.swVersion };
        _meta = { "macAddress" : info.mac };
        return this;
    }

    /***************************************************************************************
     * setBasicDevInfo
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function setBasicDevInfo() {
        _deviceID = imp.configparams.deviceid.tostring();
        _deviceInfo = {"manufacturer" : DEVICE_MANUFACTURER};
        _meta = {};
        return this;
    }

    /***************************************************************************************
     * createDev - creates or updates device on Watson platform
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function createDev() {
        _watson.getDevice(DEVICE_TYPE_ID, _deviceID, function(err, res) {
            switch (err) {
                case _watson.MISSING_RESOURCE_ERROR:
                    // dev doesn't exist yet create it
                    local info = {"deviceId": _deviceID,  "deviceInfo" : _deviceInfo, "metadata" : _meta};
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
                    local info = {"deviceInfo" : _deviceInfo, "metadata" : _meta};
                    _watson.updateDevice(DEVICE_TYPE_ID, _deviceID, info, function(error, response) {
                        if (error != null) {
                            server.error(error);
                            return;
                        }
                    }.bindenv(this));
                    break;
                default:
                    // we encountered an error
                    server.error(err);
            }
        }.bindenv(this));
    }

    // ------------------------- PRIVATE FUNCTIONS ------------------------------------------

    /***************************************************************************************
     * sendReadingHandler
     * Returns: this
     * Parameters:
     *      message: table - message received from bullwinkle listener
     *      reply: function that sends a reply to bullwinle message sender
     **************************************************************************************/
    function _sendReadingHandler(message, reply) {
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

    /***************************************************************************************
     * sendReadingHandler
     * Returns: this
     * Parameters:
     *      message: table - message received from bullwinkle listener
     *      reply: function that sends a reply to bullwinle message sender
     **************************************************************************************/
    function _updateDevInfoHandler(message, reply) {
        if (typeof message.data == "table") {
            local info = message.data;
            if ("devID" in info) {
                _deviceID = info.devID.tostring();
                info.rawdelete("devID");
            }
            if ("location" in info) {
                _deviceInfo.descriptiveLocation <- info.location;
                info.rawdelete("location");
            }
            if ("swVersion" in info) {
                _deviceInfo.fwVersion <- info.swVersion;
                info.rawdelete("swVersion");
            }
            if ("mac" in info) {
                _meta.macAddress <- info.mac;
                info.rawdelete("mac");
            }
            foreach(key, value in info) {
                _meta[key] <- value;
            }
        }
        createDev();
    }
}

// RUNTIME
// ----------------------------------------------

// Watson API Auth Keys
const API_KEY = "<YOUR API KEY HERE>";
const AUTH_TOKEN = "<YOUR AUTH KEY HERE>";
const ORG_ID = "<YOUR ORG ID HERE>";

//  Start Up App
app <- Application(API_KEY, AUTH_TOKEN, ORG_ID);