class IBMWatson {

    static version = [1, 0, 0];

    _apiKey = null;
    _authToken = null;
    _baseURL = null;

    constructor(apiKey, authToken, orgID, version = "v0002") {
        _apiKey = apiKey;
        _authToken = authToken;

        local protocol = (orgID == "quickstart") ? "http" : "https";
        _baseURL = format("%s://%s.internetofthings.ibmcloud.com/api/%s", protocol, orgID, version);
    }

    /* @params : required - string - device type ID
                 required - string - device ID
                 required - string - eventID
                 required - table - event data (formatted: {"d" : "data here", "ts": "valid ISO8601 timestamp" })
                 optional - table - headers to be used in request
                 optional - function - function to be called when response received
    */
    // @return : null
    function postData(typeID, deviceID, eventID, data, headers = {}, cb = null) {
        // POST "device/types/${typeId}/devices/${deviceId}/events/${eventId}"
        if (typeof headers == "function") {
            cb = headers;
            headers = {};
        }
        local url = format("%s/device/types/%s/devices/%s/events/%s", _baseURL, typeID, deviceID, eventID);
        local req = http.post(url, _createHeaders(headers), http.jsonencode(data));
        req.sendasync(cb);
    }

    /* @params : required - string - device type ID
                 required - table - device info
                 optional - table - headers to be used in request
                 optional - function - function to be called when response received
    */
    // @return : null
    function addDevice(typeID, deviceInfo, headers = {}, cb = null) {
        // POST /device/types/{typeId}/devices
         if (typeof headers == "function") {
            cb = headers;
            headers = {};
        }
        local url = format("%s/device/types/%s/devices", _baseURL, typeID);
        local req = http.post(url, _createHeaders(headers), http.jsonencode(deviceInfo));
        req.sendasync(cb);
    }

    /* @params : required - string - device type ID
                 required - string - device ID
                 required - table - updated device info
                 optional - table - headers to be used in request
                 optional - function - function to be called when response received
    */
    // @return : null
    function updateDevice(typeID, deviceID, deviceInfo, headers = {}, cb = null) {
        // PUT /device/types/{typeId}/devices/{deviceId}
        if (typeof headers == "function") {
            cb = headers;
            headers = {};
        }
        local url = format("%s/device/types/%s/devices/%s", _baseURL, typeID, deviceID);
        local req = http.put(url, _createHeaders(headers), http.jsonencode(deviceInfo));
        req.sendasync(cb);
    }

    /* @params : required - string - device type ID
                 required - string - device ID
                 optional - table - headers to be used in request
                 optional - function - function to be called when response received
    */
    // @return : null
    function deleteDevice(typeID, deviceID, headers = {}, cb = null) {
        // DELETE /device/types/{typeId}/devices/{deviceId}
        if (typeof headers == "function") {
            cb = headers;
            headers = {};
        }
        local url = format("%s/device/types/%s/devices/%s", _baseURL, typeID, deviceID);
        local req = http.httpdelete(url, _createHeaders(headers), http.jsonencode(deviceInfo));
        req.sendasync(cb);
    }

    // @params : optional - integer - epoch timestamp
    // @return : string - time formatted as 2015-12-03T00:54:51Z
    function formatTimestamp(ts = null) {
        local d = ts ? date(ts) : date();
        return format("%04d-%02d-%02dT%02d:%02d:%02dZ", d.year, d.month+1, d.day, d.hour, d.min, d.sec);
    }

    // @params : optional - table - headers
    // @return : table of headers
    function _createHeaders(headers = {}) {
        local auth = http.base64encode(format("%s:%s", _apiKey, _authToken));
        if (!("Authorization" in headers)) headers["Authorization"] <- format("Basic %s", auth);
        if (!("Content-Type" in headers)) headers["Content-Type"] <- "application/json";
        return headers;
    }
}