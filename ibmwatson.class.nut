class IBMWatson {

    static version = [1, 0, 0];

    _apiKey = null;
    _authToken = null;
    _baseURL = null;

    /***************************************************************************************
     * Constructor
     * Returns: null
     * Parameters:
     *      apiKey : string - Watson API key (generate via Accees -> API Keys)
     *      authToken : string - Watson Authorization Token (provided when API Key is created)
     *      orgID : string - Organization ID
     *      version (optional) : string - Watson API version number
     **************************************************************************************/
    constructor(apiKey, authToken, orgID, version = "v0002") {
        _apiKey = apiKey;
        _authToken = authToken;

        local protocol = (orgID == "quickstart") ? "http" : "https";
        _baseURL = format("%s://%s.internetofthings.ibmcloud.com/api/%s", protocol, orgID, version);
    }

    /***************************************************************************************
     * postData
     * Returns: null
     * Parameters:
     *      typeID : string - device type ID
     *      deviceID : string - ID of device that is posting data
     *      eventID : string - ID to identify event datastream
     *      data : table - event data (formatted: {"d" : "data here", "ts": "valid ISO8601 timestamp" })
     *      headers (optional) : table - additional headers to add to the http request
     *      cb (optional) : function - function to execute when response received
     **************************************************************************************/
    function postData(typeID, deviceID, eventID, data, headers = {}, cb = null) {
        // POST "device/types/${typeId}/devices/${deviceId}/events/${eventId}"
        if (typeof headers == "function") {
            cb = headers;
            headers = {};
        }
        cb = _checkCallback(cb);
        local url = format("%s/application/types/%s/devices/%s/events/%s", _baseURL, typeID, deviceID, eventID);
        local req = http.post(url, _createHeaders(headers), http.jsonencode(data));
        req.sendasync(cb);
    }

    /***************************************************************************************
     * addDevice
     * Returns: null
     * Parameters:
     *      typeID : string - device type ID
     *      deviceInfo : table - device info
     *      headers (optional) : table - additional headers to add to the http request
     *      cb (optional) : function - function to execute when response received
     **************************************************************************************/
    function addDevice(typeID, deviceInfo, headers = {}, cb = null) {
        // POST /device/types/{typeId}/devices
         if (typeof headers == "function") {
            cb = headers;
            headers = {};
        }
        cb = _checkCallback(cb);
        // add device id if not included (agent id)
        local url = format("%s/device/types/%s/devices", _baseURL, typeID);
        local req = http.post(url, _createHeaders(headers), http.jsonencode(deviceInfo));
        req.sendasync(cb);
    }

    /***************************************************************************************
     * updateDevice
     * Returns: null
     * Parameters:
     *      typeID : string - device type ID
     *      deviceID : string - ID of device to update
     *      deviceInfo : table - updated device info
     *      headers (optional) : table - additional headers to add to the http request
     *      cb (optional) : function - function to execute when response received
     **************************************************************************************/
    function updateDevice(typeID, deviceID, deviceInfo, headers = {}, cb = null) {
        // PUT /device/types/{typeId}/devices/{deviceId}
        if (typeof headers == "function") {
            cb = headers;
            headers = {};
        }
        cb = _checkCallback(cb);
        local url = format("%s/device/types/%s/devices/%s", _baseURL, typeID, deviceID);
        local req = http.put(url, _createHeaders(headers), http.jsonencode(deviceInfo));
        req.sendasync(cb);
    }

    /***************************************************************************************
     * deleteDevice
     * Returns: null
     * Parameters:
     *      typeID : string - device type ID
     *      deviceID : string - ID of device to delete
     *      headers (optional) : table - additional headers to add to the http request
     *      cb (optional) : function - function to execute when response received
     **************************************************************************************/
    function deleteDevice(typeID, deviceID, headers = {}, cb = null) {
        // DELETE /device/types/{typeId}/devices/{deviceId}
        if (typeof headers == "function") {
            cb = headers;
            headers = {};
        }
        cb = _checkCallback(cb);
        local url = format("%s/device/types/%s/devices/%s", _baseURL, typeID, deviceID);
        local req = http.httpdelete(url, _createHeaders(headers), http.jsonencode(deviceInfo));
        req.sendasync(cb);
    }

    /***************************************************************************************
     * addDeviceType
     * Returns: null
     * Parameters:
     *      typeInfo : table - device type info - must include "id"
     *      headers (optional) : table - additional headers to add to the http request
     *      cb (optional) : function - function to execute when response received
     **************************************************************************************/
    function addDeviceType(typeInfo, headers = {}, cb = null) {
        // POST /device/types
        if (typeof headers == "function") {
            cb = headers;
            headers = {};
        }
        cb = _checkCallback(cb);
        if (!("classId" in typeInfo)) typeInfo.classId <- "Device";
        local url = format("%s/device/types", _baseURL);
        local req = http.post(url, _createHeaders(headers), http.jsonencode(typeInfo));
        req.sendasync(cb);
    }

    /***************************************************************************************
     * getDeviceType
     * Returns: null
     * Parameters:
     *      typeID : string - ID of device type
     *      headers (optional) : table - additional headers to add to the http request
     *      cb (optional) : function - function to execute when response received
     **************************************************************************************/
    function getDeviceType(typeID, headers = {}, cb = null) {
        // GET /device/types/{typeId}
        if (typeof headers == "function") {
            cb = headers;
            headers = {};
        }
        cb = _checkCallback(cb);
        local url = format("%s/device/types/%s", _baseURL, typeID);
        local req = http.get(url, _createHeaders());
        local res = req.sendasync(cb);
    }

    /***************************************************************************************
     * formatTimestamp
     * Returns: time formatted as "2015-12-03T00:54:51Z"
     * Parameters:
     *      ts (optional) : integer - epoch timestamp
     **************************************************************************************/
    function formatTimestamp(ts = null) {
        local d = ts ? date(ts) : date();
        return format("%04d-%02d-%02dT%02d:%02d:%02dZ", d.year, d.month+1, d.day, d.hour, d.min, d.sec);
    }

    /***************************************************************************************
     * _createHeaders
     * Returns: request header table
     * Parameters:
     *      headers (optional) : table - additional headers
     **************************************************************************************/
    function _createHeaders(headers = {}) {
        local auth = http.base64encode(format("%s:%s", _apiKey, _authToken));
        if (!("Authorization" in headers)) headers["Authorization"] <- format("Basic %s", auth);
        if (!("Content-Type" in headers)) headers["Content-Type"] <- "application/json";
        return headers;
    }

    /***************************************************************************************
     * _checkCallback
     * Returns: a callback function
     * Parameters:
     *      cb : function or null - ensures cb is always a function
     **************************************************************************************/
    function _checkCallback(cb) {
        return (cb == null || typof cb != "function") ? _defaultCallback : cb;
    }

    /***************************************************************************************
     * _defaultCallback - does nothing with response but ensures that
     *                               async requests always have a valid callback function
     * Returns: null
     * Parameters:
     *      res : table
     **************************************************************************************/
    function _defaultCallback(res) {
        return;
    }
}