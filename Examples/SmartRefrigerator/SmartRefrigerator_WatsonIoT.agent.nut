#require "bullwinkle.class.nut:2.3.0"
#require "promise.class.nut:3.0.0"
#require "IBMWatson.class.nut:1.0.0"


/***************************************************************************************
 * SmartFrigDataManager Class:
 *      Handle incoming device readings
 *      Set sensor threshold values
 *      Set callback handlers for events and streaming data
 *      Check for temperature, humidity, and door events
 *      Average temperature and humidity readings
 **************************************************************************************/
class SmartFrigDataManager {

    // Default settings
    static DEFAULT_LX_THRESHOLD = 50; // LX level indicating door open
    static DEFAULT_TEMP_THRESHOLD = 11;
    static DEFAULT_HUMID_THRESHOLD = 70;

    // NOTE: changing the device reading or reporting intervals will impact timing of event and alert conditions
    static DOOR_OPEN_ALERT = 10; // Number of reading cycles before activating a door alert (currently 30s: DOOR_OPEN_ALERT * device reading interval = seconds before sending door alert)
    static CLEAR_DOOR_OPEN_EVENT = 180; // Clear door open event after num seconds (prevents temperature or humidity alerts right after is opened)
    static TEMP_ALERT_CONDITION = 300; // Number of seconds the temperature must be over threshold before triggering event
    static HUMID_ALERT_CONDITION = 300; // Number of seconds the humidity must be over threshold before triggering event

    // Class variables
    _bull = null;

    // Threshold varaibles
    _tempThreshold = null;
    _humidThreshold = null;
    _lxThreshold = null;
    _thresholdsUpdated = null;

    // Alert flags and counters
    _doorOpenTS = null;
    _doorOpenCounter = null;
    _doorOpenAlertTriggered = null;
    _tempAlertTriggered = null;
    _humidAlertTriggered = null;
    _tempEventTime = null;
    _humidEventTime = null;

    // Event handlers
    _doorOpenHandler = null;
    _streamReadingsHandler = null;
    _tempAlertHandler = null;
    _humidAlertHandler = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      bullwinkle : instance - of Bullwinkle class
     **************************************************************************************/
    constructor(bullwinkle) {
        _bull = bullwinkle;
        // set default thresholds
        setThresholds(DEFAULT_TEMP_THRESHOLD, DEFAULT_HUMID_THRESHOLD, DEFAULT_LX_THRESHOLD);

        // set event/alert counter
        _doorOpenCounter = 0;

        openListeners();
    }

     /***************************************************************************************
     * openListeners
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function openListeners() {
        _bull.on("readings", _readingsHandler.bindenv(this));
        _bull.on("lxThreshold", _lxThresholdHandler.bindenv(this));
    }

    /***************************************************************************************
     * setThresholds
     * Returns: null
     * Parameters:
     *      temp : integer - new tempertature threshold value
     *      humid : integer - new humid threshold value
     *      lx : integer - new light level door  value
     **************************************************************************************/
    function setThresholds(temp, humid, lx) {
        _tempThreshold = temp;
        _humidThreshold = humid;
        _lxThreshold = lx;
        _thresholdsUpdated = true;
    }

    /***************************************************************************************
     * setDoorOpenHandler
     * Returns: null
     * Parameters:
     *      cb : function - called when door open alert triggered
     **************************************************************************************/
    function setDoorOpenHandler(cb) {
        _doorOpenHandler = cb;
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

    /***************************************************************************************
     * _lxThresholdHandler
     * Returns: null
     * Parameters:
     *      message : table - message received from bullwinkle listener
     *      reply: function that sends a reply to bullwinle message sender
     **************************************************************************************/
    function _lxThresholdHandler(message, reply) {
        if (_thresholdsUpdated) {
            reply(_lxThreshold);
            _thresholdsUpdated = false;
        } else {
            reply(null);
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
        // grab readings array from message
        local readings = message.data;

        // set up variables for calculating reading average
        local tempAvg = 0;
        local humidAvg = 0
        local numReadings = 0;

        // set up variables for door event
        local doorOpen = null;
        local ts = null;

        // process readings
        // reading table keys : "brightness", "humidity", "temperature", "ts"
        foreach(reading in readings) {
            // calculate temperature and humidity totals
            if ("temperature" in reading && "humidity" in reading) {
                numReadings++;
                tempAvg += reading.temperature;
                humidAvg += reading.humidity;
            }

            // get time stamp of reading
            ts = reading.ts;

            // determine door status
            if ("brightness" in reading) doorOpen = _checkDoorEvent(ts, reading.brightness);
        }

        if (numReadings != 0) {
            // average the temperature and humidity readings
            tempAvg = tempAvg/numReadings;
            humidAvg = humidAvg/numReadings;

            // check for events
            _checkTempEvent(tempAvg, ts);
            _checkHumidEvent(humidAvg, ts);
        }

        // send reading to handler
        _streamReadingsHandler({"temperature" : tempAvg, "humidity" : humidAvg, "door" : doorOpen}, ts);
        // send ack to device (device erases this set of readings when ack received)
        reply("OK");
    }

    /***************************************************************************************
     * _checkTempEvent
     * Returns: null
     * Parameters:
     *      reading : float - a temperature reading
     **************************************************************************************/
    function _checkTempEvent(reading, ts) {
        // check for temp event
        if (reading > _tempThreshold) {
            // check that frig door hasn't been open recently & that alert hasn't been sent
            if (_doorOpenTS == null && !_tempAlertTriggered) {
                // create event timer
                if (_tempEventTime == null) {
                    _tempEventTime = ts + TEMP_ALERT_CONDITION;
                }
                // check that alert conditions have exceeded the time needed to trigger alert
                if (ts >= _tempEventTime) {
                    // Trigger Temp Alert
                    _tempAlertHandler(reading, ts, _tempThreshold);
                    // Set flag so we don't trigger the same alert again
                    _tempAlertTriggered = true;
                    // Reset Temp Event timer
                    _tempEventTime = null;
                }
            }
        } else {
            // Reset Temp Alert Conditions
            _tempAlertTriggered = false;
            _tempEventTime = null;
        }
    }

    /***************************************************************************************
     * _checkHumidEvent
     * Returns: null
     * Parameters:
     *      reading : float - a humidity reading
     **************************************************************************************/
    function _checkHumidEvent(reading, ts) {
        // check for humidity event
        if (reading > _humidThreshold) {
            // check that frig door hasn't been open recently & that alert hasn't been sent
            if (_doorOpenTS == null && !_humidAlertTriggered) {
                // create event timer
                if (_humidEventTime == null) {
                    _humidEventTime = ts + HUMID_ALERT_CONDITION;
                }
                // check that alert conditions have exceeded the time needed to trigger alert
                if ( ts >= _humidEventTime) {
                    // Trigger Humidity Alert
                    _humidAlertHandler(reading, ts, _humidThreshold);
                    // Set flag so we don't trigger the same alert again
                    _humidAlertTriggered = true;
                    // Reset Humidity timer
                    _humidEventTime = null;
                }
            }
        } else {
            // Reset Hmidity Alert Conditions
            _humidAlertTriggered = false;
            _humidEventTime = null;
        }
    }

    /***************************************************************************************
     * _checkDoorEvent
     * Returns: sting - door status
     * Parameters:
     *      lxLevel : float - a light reading
     *      readingTS : integer - the timestamp of the reading
     **************************************************************************************/
    function _checkDoorEvent(readingTS, lxLevel = null) {
        // Boolean if door open event occurred
        local doorOpen = (lxLevel == null || lxLevel > _lxThreshold);

        // check if door open
        if (doorOpen) {
            _doorOpenCounter++;
            // check if door timer started
            if (!_doorOpenTS) {
                // start door timer
                _doorOpenTS = readingTS;
            // check that door alert conditions have been met
            } else if (!_doorOpenAlertTriggered && _doorOpenCounter > DOOR_OPEN_ALERT) {
                // trigger door open alert
                _doorOpenAlertTriggered = readingTS;
                _doorOpenHandler(readingTS - _doorOpenTS);
            }
        } else {
            // since door is closed, reset door open alert conditions
            _doorOpenCounter = 0;
            _doorOpenAlertTriggered = null;

            // check that door timer can be reset
            if (_doorOpenTS && (readingTS - _doorOpenTS) >= CLEAR_DOOR_OPEN_EVENT ) {
                // since door closed for set ammount of time, reset door event timer
                _doorOpenTS = null;
            }
        }
        return (doorOpen) ? "Open" : "Closed";
    }

}


/***************************************************************************************
 * SmartFrigDeviceMngr Class:
 *      Handle incoming device info
 *      Create DeviceType on Watson platform
 *      Create/Update Device on Watson platform
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

        // Set variable data types
        _meta = {};
        _deviceInfo = {};

        setBasicDevInfo();
        createDevType()
            .then(function(status) {
                server.log(http.jsonencode(status));
                // create device
                createDev();
            }.bindenv(this),
            function(rejected) {
                server.error(rejected);
            }.bindenv(this));

        // Open Listener
        _bull.on("updateDevInfo", _updateDevInfoHandler.bindenv(this));
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
     * setDeviceInfo
     * Returns: this
     * Parameters:
     *      info: table - table with device information
     **************************************************************************************/
    function setDeviceInfo(info) {
        deviceID = info.devID.tostring();
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

    /***************************************************************************************
     * _updateDevInfoHandler
     * Returns: this
     * Parameters:
     *      message: table - message received from bullwinkle listener
     *      reply: function that sends a reply to bullwinle message sender
     **************************************************************************************/
    function _updateDevInfoHandler(message, reply) {
        // store device info locally
        if (typeof message.data == "table") {
            local info = message.data;
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
        // Create/Update Watson device
        createDev();
        // Send ack to device
        reply("OK");
    }

}


/***************************************************************************************
 * Application Class:
 *      Sends data and alerts to Watson platform
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
        dataMngr.setDoorOpenHandler(doorOpenHandler.bindenv(this));
        dataMngr.setStreamReadingsHandler(streamReadingsHandler.bindenv(this));
        dataMngr.setTempAlertHandler(tempAlertHandler.bindenv(this));
        dataMngr.setHumidAlertHandler(humidAlertHandler.bindenv(this));
    }

    /***************************************************************************************
     * streamReadingsHandler
     * Returns: null
     * Parameters:
     *      reading : table - temperature, humidity and door status
     *      ts : integer - epoch time stamp
     **************************************************************************************/
    function streamReadingsHandler(reading, ts) {
        // log the incoming reading
        server.log(http.jsonencode(reading));

        // set up data structure expected by Watson
        local data = { "d": reading,
                       "ts": watson.formatTimestamp(ts) };

        // Post data if Watson device configured
        if (devMngr.deviceConfigured) {
            watson.postData(typeID, devMngr.deviceID, STREAMING_EVENT_ID, data, watsonResponseHandler.bindenv(this));
        }
    }

    /***************************************************************************************
     * doorOpenHandler
     * Returns: null
     * Parameters:
     *      doorOpenFor : integer - number of seconds the door has been open for
     **************************************************************************************/
    function doorOpenHandler(doorOpenFor) {
        local description = format("Door open for %s seconds.", doorOpenFor.tostring());
        server.log(format("%s: %s", DOOR_OPEN_ALERT, description));

        sendAlert(DOOR_OPEN_EVENT_ID, DOOR_OPEN_ALERT, description);
    }

    /***************************************************************************************
     * tempAlertHandler
     * Returns: null
     * Parameters:
     *      latestReading : float - current tempertature reading
     *      alertTiggeredTime : integer - epoch time stamp of alert
     *      threshold : integer - temperature threshold value
     **************************************************************************************/
    function tempAlertHandler(latestReading, alertTiggeredTime, threshold) {
        local description = format("Temperature %s °C above threshold.", (latestReading - threshold).tostring());
        server.log(format("%s: %s", TEMP_ALERT, description));

        sendAlert(TEMP_ALERT_EVENT_ID, TEMP_ALERT, description, alertTiggeredTime);
    }

    /***************************************************************************************
     * humidAlertHandler
     * Returns: null
     * Parameters:
     *      latestReading : float - current humidity reading
     *      alertTiggeredTime : integer - epoch time stamp of alert
     *      threshold : integer - humidity threshold value
     **************************************************************************************/
    function humidAlertHandler(latestReading, alertTiggeredTime, threshold) {
        local description = format("Humidity %s above threshold.", (latestReading - threshold).tostring());
        server.log(format("%s: %s", HUMID_ALERT, description));

        sendAlert(HUMID_ALERT_EVENT_ID, HUMID_ALERT, description, alertTiggeredTime);
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
        if(res.statuscode == 200) server.log("Watson request successful");
    }
}


// RUNTIME
// ----------------------------------------------

// Watson API Auth Keys
const API_KEY = "<YOUR API KEY HERE>";
const AUTH_TOKEN = "<YOUR AUTHENTICATION TOKEN HERE>";
const ORG_ID = "<YOUR ORG ID>";

app <- Application(API_KEY, AUTH_TOKEN, ORG_ID);