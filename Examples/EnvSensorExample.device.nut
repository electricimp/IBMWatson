// Temperature Humidity sensor Library
#require "Si702x.class.nut:1.0.0"
// Air Pressure sensor Library
#require "LPS25H.class.nut:2.0.1"
// Ambient Light sensor Library
#require "APDS9007.class.nut:2.2.1"

#require "promise.class.nut:3.0.0"
#require "bullwinkle.class.nut:2.3.0"


class EnvTail {
    static READING_INTERVAL = 300;

    _tempHumid = null;
    _ambLx = null;
    _press = null;
    _led = null;
    _bull = null;

    constructor(enableTempHumid, enableAmbLx, enablePressure, bullwinkle) {
        _bull = bullwinkle;
        _configureLED();
        _enableSensors(enableTempHumid, enableAmbLx, enablePressure);
    }

    function takeReadings() {
        // take readings asynchonously
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

    function flashLed() {
        led.write(1);
        imp.sleep(0.5);
        led.write(0);
    }

    // ----------- PRIVATE FUNCTIONS ------------

    function _buildReadingQue() {
        local que = [];
        if (_ambLx) que.push( _takeReading(_ambLx) );
        if (_tempHumid) que.push( _takeReading(_tempHumid) );
        if (_press) que.push( _takeReading(_press) );
        return que;
    }

    function _takeReading(sensor) {
        return Promise(function(resolve, reject) {
            sensor.read(function(reading) {
                return resolve(reading);
            }.bindenv(sensor));
        }.bindenv(this))
    }

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

    function _enableSensors(tempHumid, ambLx, press) {
        if (tempHumid || press) _configure_i2cSensors(tempHumid, press);
        if (ambLx) _configureAmbLx();
    }

    function _configure_i2cSensors(tempHumid, press) {
        local i2c = hardware.i2c89;
        i2c.configure(CLOCK_SPEED_400_KHZ);
        if (tempHumid) _tempHumid = Si702x(i2c);
        if (press) _press = LPS25H(i2c);
    }

    function _configureAmbLx() {
        local lxOutPin = hardware.pin5;
        local lxEnPin = hardware.pin7;
        lxOutPin.configure(ANALOG_IN);
        lxEnPin.configure(DIGITAL_OUT, 1);

        _ambLx = APDS9007(lxOutPin, 47000, lxEnPin);
        _ambLx.enable();
    }

    function _configureLED() {
        _led = hardware.pin2;
        _led.configure(DIGITAL_OUT, 0);
        return this;
    }
}

class DeviceInfo {

    _devInfo = null;
    _bull = null;

    constructor(location, bullwinkle) {
        _devInfo = getDeviceInfo(location);
        _bull = bullwinkle;

        _bull.on("devInfo", _sendDeviceInfo.bindenv(this));
    }

    function getDeviceInfo(location) {
        local info = {};
        info.mac <- imp.getmacaddress();
        info.swVersion <- imp.getsoftwareversion();
        info.devID <- hardware.getdeviceid();
        info.location <- location;
        // imp.scanwifinetworks();
        return info;
    }

    function _sendDeviceInfo(message, reply) {
        reply(_devInfo);
    }
}

// RUNTIME
// ----------------------------------------------

bull <- Bullwinkle();
dev <- DeviceInfo("Los Altos EI HQ - Reception", bull);
tail <- EnvTail(true, true, true, bull);

// give agent time to configure watson connection
imp.wakeup(10, tail.takeReadings.bindenv(tail));
