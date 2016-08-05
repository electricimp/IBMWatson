// Temperature Humidity sensor Library
#require "Si702x.class.nut:1.0.0"
// Air Pressure sensor Library
#require "LPS25H.class.nut:2.0.1"
// Ambient Light sensor Library
#require "APDS9007.class.nut:2.2.1"

#require "promise.class.nut:3.0.0"
#require "bullwinkle.class.nut:2.3.0"

/***************************************************************************************
 * EnvTail Class:
 *      Initializes and enables specified sensors
 *      Takes sensor readings at a specified interval (default is 300s)
 *      When readings collected from sensors, sends readings to agent
 **************************************************************************************/
class EnvTail {
    static DEFAULT_READING_INTERVAL = 300;

    _tempHumid = null;
    _ambLx = null;
    _press = null;
    _led = null;
    _bull = null;
    _readingInterval = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      enableTempHumid : boolean - if the temperature/humidity sensor should be enabled
     *      enableAmbLx : boolean - if the ambient light sensor should be enabled
     *      enablePressure : boolean - if the air pressure sensor should be enabled
     *      bullwinkle : instance - an initialized bullwinkle instance
     **************************************************************************************/
    constructor(enableTempHumid, enableAmbLx, enablePressure, bullwinkle) {
        _bull = bullwinkle;
        _configureLED();
        _enableSensors(enableTempHumid, enableAmbLx, enablePressure);
        setReadingInterval();
    }

    /***************************************************************************************
     * takeReadings - takes readings, sends to agent, schedules next reading
     * Returns: null
     * Parameters: none
     **************************************************************************************/
    function takeReadings() {
        // Take readings asynchonously if sensor enabled
        local que = _buildReadingQue();

        // When all readings have returned values send to agent
        Promise.all(que)
            .then(function(readings) {
                // send readings to agent
                bull.send("reading", _parseReadings(readings));
                // flash led to let user know a reading was sent
                flashLed();
            }.bindenv(this))
            .finally(function(val) {
                // set timer for next reading
                imp.wakeup(READING_INTERVAL, takeReadings.bindenv(this));
            }.bindenv(this));
    }

    /***************************************************************************************
     * setReadingInterval
     * Returns: this
     * Parameters:
     *      interval (optional) : the time in seconds to wait between readings,
     *                                     if nothing passed in sets the readingInterval to
     *                                     the default of 300s
     **************************************************************************************/
    function setReadingInterval(interval =  null) {
        _readingInterval = (interval == null) ? DEFAULT_READING_INTERVAL : interval;
        return this;
    }

    /***************************************************************************************
     * getReadingInterval
     * Returns: the current reading interval
     * Parameters: none
     **************************************************************************************/
    function getReadingInterval() {
        return _readingInterval;
    }

    /***************************************************************************************
     * flashLed - blinks the led, this function blocks for 0.5s
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function flashLed() {
        led.write(1);
        imp.sleep(0.5);
        led.write(0);
        return this;
    }

    // ------------------------- PRIVATE FUNCTIONS ------------------------------------------

    /***************************************************************************************
     * _buildReadingQue
     * Returns: an array of Promises for each sensor that is taking a reading
     * Parameters: none
     **************************************************************************************/
    function _buildReadingQue() {
        local que = [];
        if (_ambLx) que.push( _takeReading(_ambLx) );
        if (_tempHumid) que.push( _takeReading(_tempHumid) );
        if (_press) que.push( _takeReading(_press) );
        return que;
    }

    /***************************************************************************************
     * _takeReading
     * Returns: Promise that resolves with the sensor reading
     * Parameters:
     *      sensor: instance - the sensor to take a reading from
     **************************************************************************************/
    function _takeReading(sensor) {
        return Promise(function(resolve, reject) {
            sensor.read(function(reading) {
                return resolve(reading);
            }.bindenv(sensor));
        }.bindenv(this))
    }

    /***************************************************************************************
     * _parseReadings
     * Returns: a table of successful readings
     * Parameters:
     *      readings: array - with each sensor reading/error
     **************************************************************************************/
    function _parseReadings(readings) {
        local data = {};
        foreach(reading in readings) {
            if ("err" in reading) {
                server.error(reading.err);
            } else {
                foreach(sensor, value in reading) {
                    data[sensor] <- value;
                }
            }
        }
        return data;
    }

    /***************************************************************************************
     * _enableSensors
     * Returns: this
     * Parameters:
     *      tempHumid: boolean - if temperature/humidity sensor should be enabled
     *      ambLx: boolean - if ambient light sensor should be enabled
     *      press: boolean - if air pressure sensor should be enabled
     **************************************************************************************/
    function _enableSensors(tempHumid, ambLx, press) {
        if (tempHumid || press) _configure_i2cSensors(tempHumid, press);
        if (ambLx) _configureAmbLx();
        return this;
    }

    /***************************************************************************************
     * _configure_i2cSensors
     * Returns: this
     * Parameters:
     *      tempHumid: boolean - if temperature/humidity sensor should be enabled
     *      press: boolean - if air pressure sensor should be enabled
     **************************************************************************************/
    function _configure_i2cSensors(tempHumid, press) {
        local i2c = hardware.i2c89;
        i2c.configure(CLOCK_SPEED_400_KHZ);
        if (tempHumid) _tempHumid = Si702x(i2c);
        if (press) _press = LPS25H(i2c);
        return this;
    }

    /***************************************************************************************
     * _configureAmbLx
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function _configureAmbLx() {
        local lxOutPin = hardware.pin5;
        local lxEnPin = hardware.pin7;
        lxOutPin.configure(ANALOG_IN);
        lxEnPin.configure(DIGITAL_OUT, 1);

        _ambLx = APDS9007(lxOutPin, 47000, lxEnPin);
        _ambLx.enable();
        return this;
    }

    /***************************************************************************************
     * _configureLED
     * Returns: this
     * Parameters: none
     **************************************************************************************/
    function _configureLED() {
        _led = hardware.pin2;
        _led.configure(DIGITAL_OUT, 0);
        return this;
    }
}

/***************************************************************************************
 * DeviceInfo Class:
 *      Sets basic device info
 *      Sends device info to agent
 **************************************************************************************/
class DeviceInfo {
    _devInfo = null;
    _bull = null;
    _devInfoSent = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      location : string - description of the device location
     *      bullwinkle : instance - an initialized bullwinkle instance
     **************************************************************************************/
    constructor(location, bullwinkle) {
        _bull = bullwinkle;
        _setDefaultDeviceInfo(location);
        _devInfoSent = false;

        _bull.on("devInfo", _sendReqestedInfo.bindenv(this));

        // if device reboots make sure to send dev data
        imp.wakeup(5, function() {
            if (!_devInfoSent) sendDeviceInfo();
        }.bindenv(this));
    }

    /***************************************************************************************
     * sendDeviceInfo
     * Returns: this
     * Parameters:
     *      info (optional) : table - additional/new device info to send to agent
     **************************************************************************************/
    function sendDeviceInfo(info = null) {
        if (typeof info == "table") _addDevInfo(info);
        _bull.send("updateDevInfo", _devInfo);
        return this;
    }

    // ------------------------- PRIVATE FUNCTIONS ------------------------------------------

    /***************************************************************************************
     * _setDefaultDeviceInfo - mac address, sw version, device id, location
     * Returns: this
     * Parameters:
     *      location : string - description of the device location
     **************************************************************************************/
    function _setDefaultDeviceInfo(location) {
        if (typeof _devInfo != "table") _devInfo = {};
        _devInfo.mac <- imp.getmacaddress();
        _devInfo.swVersion <- imp.getsoftwareversion();
        _devInfo.devID <- hardware.getdeviceid();
        _devInfo.location <- location;

        return this;
    }

    /***************************************************************************************
     * _sendReqestedInfo
     * Returns: null
     * Parameters:
     *      message: table - message received from bullwinkle listener
     *      reply: function that sends a reply to bullwinle message sender
     **************************************************************************************/
    function _sendReqestedInfo(message, reply) {
        _devInfoSent = true;
        reply(_devInfo);
    }

    /***************************************************************************************
     * _addDevInfo
     * Returns: this
     * Parameters:
     *      info: table - new device info
     **************************************************************************************/
    function _addDevInfo(info) {
        foreach(key, value in info) {
            _devInfo[key] = value;
        }
        return this
    }
}

// RUNTIME
// ----------------------------------------------

// Create instances of our classes
bull <- Bullwinkle();
dev <- DeviceInfo("Los Altos EI HQ - Reception", bull);
tail <- EnvTail(true, true, true, bull);

// Give agent time to configure watson connection
// Then start the sensor readings loop
imp.wakeup(10, tail.takeReadings.bindenv(tail));
