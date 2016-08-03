class IBMWatson {

    static version = [1, 0, 0];

    static INVALID_REQUEST_ERROR = "Error: Invalid Request";
    static INVALID_AUTH_TOKEN_ERROR = "Error: Invalid Authentication Token";
    static INVALID_AUTH_METHOD_ERROR = "Error: Invalid API Key or Authentication Method";
    static MISSING_RESOURCE_ERROR = "Error: Resource does not exist";
    static CONFLICT_ERROR = "Error: Conflict, resource already exists";
    static UNEXPECTED_ERROR = "Error: Unexpected error";

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
        local url = format("%s/application/types/%s/devices/%s/events/%s", _baseURL, typeID, deviceID, eventID);
        local req = http.post(url, _createHeaders(headers), http.jsonencode(data));
        req.sendasync(function(res) {
            _processResponse(res, cb);
        }.bindenv(this));
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
        // add device id if not included (agent id)
        local url = format("%s/device/types/%s/devices", _baseURL, typeID);
        local req = http.post(url, _createHeaders(headers), http.jsonencode(deviceInfo));
        req.sendasync(function(res) {
            _processResponse(res, cb);
        }.bindenv(this));
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
        local url = format("%s/device/types/%s/devices/%s", _baseURL, typeID, deviceID);
        local req = http.put(url, _createHeaders(headers), http.jsonencode(deviceInfo));
        req.sendasync(function(res) {
            _processResponse(res, cb);
        }.bindenv(this));
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
        local url = format("%s/device/types/%s/devices/%s", _baseURL, typeID, deviceID);
        local req = http.httpdelete(url, _createHeaders(headers), http.jsonencode(deviceInfo));
        req.sendasync(function(res) {
            _processResponse(res, cb);
        }.bindenv(this));
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
        if (!("classId" in typeInfo)) typeInfo.classId <- "Device";
        local url = format("%s/device/types", _baseURL);
        local req = http.post(url, _createHeaders(headers), http.jsonencode(typeInfo));
        req.sendasync(function(res) {
            _processResponse(res, cb);
        }.bindenv(this));
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
        local url = format("%s/device/types/%s", _baseURL, typeID);
        local req = http.get(url, _createHeaders());
        req.sendasync(function(res) {
            _processResponse(res, cb);
        }.bindenv(this));
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
     * _processResponse
     * Returns: null
     * Parameters:
     *      res : the response object from Watson
     *      cb : the callback function passed into the request or null
     **************************************************************************************/
    function _processResponse(res, cb) {
        local status = res.statuscode;
        local err = (status < 200 || status >= 300) ? _getError(status) : null;
        try {
            res.body = (res.body == "") ? {} : http.jsondecode(res.body);
        } catch (e) {
            if (err != null) err = e;
        }

        if (cb) cb(err, res);
    }


    /***************************************************************************************
     * _getError
     * Returns: error string
     * Parameters:
     *      statusCode : integer - status code from request
     **************************************************************************************/
    function _getError(statusCode) {
        local err = null;
        switch (statusCode) {
            case 400:
                err = INVALID_REQUEST_ERROR;
                break;
            case 401:
                err = INVALID_AUTH_TOKEN_ERROR;
                break;
            case 403:
                err = INVALID_AUTH_METHOD_ERROR
                break;
            case 404:
                err = MISSING_RESOURCE_ERROR
                break;
            case 409:
                err = CONFLICT_ERROR
                break;
            default:
                err = UNEXPECTED_ERROR;
        }
        return err;
    }
}