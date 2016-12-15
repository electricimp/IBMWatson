//line 1 "agent.nut"
// Utility Libraries
#require "bullwinkle.class.nut:2.3.2"
#require "promise.class.nut:3.0.0"
// Web Integration Library
#require "IBMWatson.class.nut:1.1.0"

// Class that receives and handles data sent from device SmartFridgeApp
//line 1 "SmartFrigDataManager.class.nut"
/***************************************************************************************
 * SmartFrigDataManager Class:
 *      Handle incoming device readings and events
 *      Set callback handlers for events and streaming data
 *      Average temperature and humidity readings
 *
 * Dependencies
 *      Bullwinle (passed into the constructor)
 **************************************************************************************/
class SmartFrigDataManager {

    static DEBUG_LOGGING = true;

    // Event types (these should match device side event types in SmartFrigDataManager)
    static EVENT_TYPE_TEMP_ALERT = "temperaure alert";
    static EVENT_TYPE_HUMID_ALERT = "humidity alert";
    static EVENT_TYPE_DOOR_ALERT = "door alert";
    static EVENT_TYPE_DOOR_STATUS = "door status";

    _streamReadingsHandler = null;
    _doorOpenAlertHandler = null;
    _tempAlertHandler = null;
    _humidAlertHandler = null;

    // Class instances
    _bull = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      bullwinkle : instance - of Bullwinkle class
     **************************************************************************************/
    constructor(bullwinkle) {
        _bull = bullwinkle;
        openListeners();
    }

     /***************************************************************************************
     * openListeners
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function openListeners() {
        _bull.on("update", _readingsHandler.bindenv(this));
    }

    /***************************************************************************************
     * setStreamReadingsHandler
     * Returns: null
     * Parameters:
     *      cb : function - called when new reading received
     **************************************************************************************/
    function setStreamReadingsHandler(cb) {
        _streamReadingsHandler = cb;
    }

    /***************************************************************************************
     * setDoorOpenAlertHandler
     * Returns: null
     * Parameters:
     *      cb : function - called when door open alert triggered
     **************************************************************************************/
    function setDoorOpenAlertHandler(cb) {
        _doorOpenAlertHandler = cb;
    }

    /***************************************************************************************
     * setTempAlertHandler
     * Returns: null
     * Parameters:
     *      cb : function - called when temperature alert triggerd
     **************************************************************************************/
    function setTempAlertHandler(cb) {
        _tempAlertHandler = cb;
    }

    /***************************************************************************************
     * setHumidAlertHandler
     * Returns: null
     * Parameters:
     *      cb : function - called when humidity alert triggerd
     **************************************************************************************/
    function setHumidAlertHandler(cb) {
        _humidAlertHandler = cb;
    }

    // ------------------------- PRIVATE FUNCTIONS ------------------------------------------

    /***************************************************************************************
     * _getAverage
     * Returns: null
     * Parameters:
     *      readings : table of readings
     *      type : key from the readings table for the readings to average
     *      numReadings: number of readings in the table
     **************************************************************************************/
    function _getAverage(readings, type, numReadings) {
        if (numReadings == 1) {
            return readings[0][type];
        } else {
            local total = readings.reduce(function(prev, current) {
                    return (!(type in prev)) ? prev + current[type] : prev[type] + current[type];
                })
            return total / numReadings;
        }
    }

    /***************************************************************************************
     * _readingsHandler
     * Returns: null
     * Parameters:
     *      message : table - message received from bullwinkle listener
     *      reply: function that sends a reply to bullwinle message sender
     **************************************************************************************/
    function _readingsHandler(message, reply) {
        local data = message.data;
        local streamingData = { "ts" : time() };
        local numReadings = data.readings.len();

        // send ack to device (device erases this set of readings/events when ack received)
        reply("OK");

        if (DEBUG_LOGGING) {
            server.log("in readings handler")
            server.log(http.jsonencode(data.readings));
            server.log(http.jsonencode(data.doorStatus));
            server.log(http.jsonencode(data.events));
            server.log("Current time: " + time())
        }

        if ("readings" in data && numReadings > 0) {

            // Update streaming data table with temperature and humidity averages
            streamingData.temperature <- _getAverage(data.readings, "temperature", numReadings);
            streamingData.humidity <- _getAverage(data.readings, "humidity", numReadings);
        }

        if ("doorStatus" in data) {
            // Update streaming data table
            streamingData.door <- data.doorStatus.currentStatus;
        }

        // send streaming data to handler
        _streamReadingsHandler(streamingData);

        if ("events" in data && data.events.len() > 0) {
            // handle events
            foreach (event in data.events) {
                switch (event.type) {
                    case EVENT_TYPE_TEMP_ALERT :
                        _tempAlertHandler(event);
                        break;
                    case EVENT_TYPE_HUMID_ALERT :
                        _humidAlertHandler(event);
                        break;
                    case EVENT_TYPE_DOOR_ALERT :
                        _doorOpenAlertHandler(event);
                        break;
                    case EVENT_TYPE_DOOR_STATUS :
                        break;
                }
            }
        }
    }

}
//line 9 "agent.nut"

/***************************************************************************************
 * SmartFrigDeviceMngr Class:
 *      Requests/stores info from device
 *      Create DeviceType on Watson platform
 *      Create/Update Device on Watson platform
 *      Creates a flag indicating if Device has been created in Watson
 *
 * Dependencies
 *      Bullwinkle Library
 **************************************************************************************/
class SmartFrigDeviceMngr {
    // Watson Device Information
    static DEVICE_TYPE_ID = "SmartFridge";
    static DEVICE_TYPE_DESCRIPTION = "Smart Refrigerator";
    static DEVICE_MANUFACTURER = "Electric Imp";

    // Class variables
    _bull = null;
    _watson = null;

    _deviceInfo = null;
    _meta = null;

    deviceID = null;
    deviceConfigured = false;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      bullwinkle : instance - of Bullwinkle class
     *      watson : instance - of Watson class
     **************************************************************************************/
    constructor(bullwinkle, watson) {
        _bull = bullwinkle;
        _watson = watson;

        setBasicDevInfo();

        // Create Watson device type and get info from device
        local que = [createDevType(), getDevInfo()];

        // Then create device in Watson
        Promise.all(que)
            .then(function(msg) {
                server.log(msg);
                createDev();
            }.bindenv(this),
            function(reject){
                server.error(rejected);
            }.bindenv(this));
    }

    /***************************************************************************************
     * getDevInfo
     * Returns: Promise that resolves with status message
     * Parameters: none
     **************************************************************************************/
    function getDevInfo() {
        return Promise(function(resolve, reject) {
            imp.wakeup(0.5, function() {
                _bull.send("getDevInfo", null)
                    .onReply(function(msg) {
                        if (msg.data != null) {
                            _updateDevInfo(msg.data);
                            return resolve("Received Device Info.")
                        } else {
                            return resolve("Device Info Error.")
                        }
                    }.bindenv(this))
                    .onFail(function(err, msg, retry) {
                        // TODO: add retry
                        return resolve("Device Info Error.")
                    }.bindenv(this))
            }.bindenv(this))
        }.bindenv(this))
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
     * setBasicDevInfo
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function setBasicDevInfo() {
        deviceID = imp.configparams.deviceid.tostring();
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
        _watson.getDevice(DEVICE_TYPE_ID, deviceID, function(err, res) {
            switch (err) {
                case _watson.MISSING_RESOURCE_ERROR:
                    // dev doesn't exist yet create it
                    local info = {"deviceId": deviceID,  "deviceInfo" : _deviceInfo, "metadata" : _meta};
                    _watson.addDevice(DEVICE_TYPE_ID, info, function(error, response) {
                        if (error != null) {
                            server.error(error);
                            return;
                        }
                        deviceConfigured = true;
                        server.log("Dev created");
                    }.bindenv(this));
                    break;
                case null:
                    // dev exists, update
                    local info = {"deviceInfo" : _deviceInfo, "metadata" : _meta};
                    _watson.updateDevice(DEVICE_TYPE_ID, deviceID, info, function(error, response) {
                        if (error != null) {
                            server.error(error);
                            return;
                        }
                        deviceConfigured = true;
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
     * _updateDevInfo
     * Returns: this
     * Parameters:
     *      info: table with new device info
     **************************************************************************************/
    function _updateDevInfo(info) {
        if ("devID" in info) {
            deviceID = info.devID.tostring();
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

}

/***************************************************************************************
 * Application Class:
 *      Sends data and alerts to IBM Watson IoT platform
 *
 * Dependencies
 *      Bullwinkle Library
 *      IBMWatson Library
 *      SmartFrigDeviceMngr Class
 *      SmartFrigDataManager Class
 **************************************************************************************/
class Application {
    // Event IDs
    static STREAMING_EVENT_ID = "RefrigeratorMonitor";
    static DOOR_OPEN_EVENT_ID = "DoorOpenAlert";
    static TEMP_ALERT_EVENT_ID = "TemperatureAlert";
    static HUMID_ALERT_EVENT_ID = "HumidityAlert";
    // Alert messages
    static DOOR_OPEN_ALERT = "Refrigerator Door Open";
    static TEMP_ALERT = "Temperature Over Threshold";
    static HUMID_ALERT = "Humidity Over Threshold";

    dataMngr = null;
    devMngr = null;
    watson = null;

    typeID = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      apiKey : string - Yor API key (created in Watson Access settings)
     *      authToken : string - Yor Authorization Token (created in Watson Access settings)
     *      orgID : string - Your Organization ID (created by Watson)
     **************************************************************************************/
    constructor(apiKey, authToken, orgID) {
        initializeClasses(apiKey, authToken, orgID);
        typeID = devMngr.DEVICE_TYPE_ID;
        setDataMngrHandlers();
    }

    /***************************************************************************************
     * initializeClasses
     * Returns: null
     * Parameters:
     *      apiKey : string - Yor API key (created in Watson Access settings)
     *      authToken : string - Yor Authorization Token (created in Watson Access settings)
     *      orgID : string - Your Organization ID (created by Watson)
     **************************************************************************************/
    function initializeClasses(apiKey, authToken, orgID) {
        // agent/device communication helper library
        local _bull = Bullwinkle();
        // Library for integration with Watson IoT platform
        watson = IBMWatson(apiKey, authToken, orgID);
        // Class to manage sensor data from device
        dataMngr = SmartFrigDataManager(_bull);
        // Class to manage device info and Watson device creation
        devMngr = SmartFrigDeviceMngr(_bull, watson);
    }

    /***************************************************************************************
     * setDataMngrHandlers
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function setDataMngrHandlers() {
        // set Data Manager handlers to the local handler functions
        dataMngr.setDoorOpenAlertHandler(doorOpenHandler.bindenv(this));
        dataMngr.setStreamReadingsHandler(streamReadingsHandler.bindenv(this));
        dataMngr.setTempAlertHandler(tempAlertHandler.bindenv(this));
        dataMngr.setHumidAlertHandler(humidAlertHandler.bindenv(this));
    }

    /***************************************************************************************
     * streamReadingsHandler
     * Returns: null
     * Parameters:
     *      reading : table - temperature, humidity and door status
     **************************************************************************************/
    function streamReadingsHandler(reading) {
        // log the incoming reading
        server.log(http.jsonencode(reading));

        // set up data structure expected by Watson
        local data = { "d": reading,
                       "ts": watson.formatTimestamp(reading.ts) };

        // Post data if Watson device configured
        if (devMngr.deviceConfigured) {
            watson.postData(typeID, devMngr.deviceID, STREAMING_EVENT_ID, data, watsonResponseHandler.bindenv(this));
        }
    }

    /***************************************************************************************
     * doorOpenHandler
     * Returns: null
     * Parameters:
     *      event: table with event details
     **************************************************************************************/
    function doorOpenHandler(event) {
        server.log(format("%s: %s", DOOR_OPEN_ALERT, event.description));
        sendAlert(DOOR_OPEN_EVENT_ID, DOOR_OPEN_ALERT, event.description, event.ts);
    }

    /***************************************************************************************
     * tempAlertHandler
     * Returns: null
     * Parameters:
     *      event: table with event details
     **************************************************************************************/
    function tempAlertHandler(event) {
        server.log(format("%s: %s", TEMP_ALERT, event.description));
        sendAlert(TEMP_ALERT_EVENT_ID, TEMP_ALERT, event.description, event.ts);
    }

    /***************************************************************************************
     * humidAlertHandler
     * Returns: null
     * Parameters:
     *      event: table with event details
     **************************************************************************************/
    function humidAlertHandler(event) {
        server.log(format("%s: %s", HUMID_ALERT, event.description));
        sendAlert(HUMID_ALERT_EVENT_ID, HUMID_ALERT, event.description, event.ts);
    }

    /***************************************************************************************
     * sendAlert
     * Returns: null
     * Parameters:
     *      eventID : string - event identifier
     *      alert : string - alert message
     *      description : string - description of alert
     *      ts (optional) : integer - epoch time stamp of alert
     **************************************************************************************/
    function sendAlert(eventID, alert, description, ts = null) {
        // set up Watson data structure
        local data = { "d" :  { "alert" : alert,
                                "frigID": devMngr.deviceID,
                                "description" : description },
                                "ts" : watson.formatTimestamp(ts) };

        // Send alert if Watson device configured
        if (devMngr.deviceConfigured) {
            watson.postData(typeID, devMngr.deviceID, eventID, data, watsonResponseHandler.bindenv(this));
        }
    }

    /***************************************************************************************
     * watsonResponseHandler
     * Returns: null
     * Parameters:
     *      err : string/null - error message
     *      res : table - response table
     **************************************************************************************/
    function watsonResponseHandler(err, res) {
        if(err) server.error(err);
        if(res.statuscode == 200) server.log("Watson request successful.");
    }
}


// RUNTIME
// ----------------------------------------------

// Watson API Auth Keys
const API_KEY = "<YOUR API KEY HERE>";
const AUTH_TOKEN = "<YOUR AUTHENTICATION TOKEN HERE>";
const ORG_ID = "<YOUR ORG ID>";

// Start Application
app <- Application(API_KEY, AUTH_TOKEN, ORG_ID);