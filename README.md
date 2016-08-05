#IBM Wason IoT

The IBMWatson library allsows you to easily integrate your agent code with [IBM® Watson™ IoT Platform](https://docs.internetofthings.ibmcloud.com/getting_started/quickstart/index.html).  This library wraps a handful of IBM® Watson™ IoT Platform HTTP REST API endpoints.  Click [here](https://docs.internetofthings.ibmcloud.com/swagger/v0002.html#/) for the full documentation of the API.

### Watson Setup

To use this library you will need to register an organization on the Watson IoT platform.  After registering you will be provided with a 6 character organization ID. You will also need to generate an API key.  When creating an API key you will be presented with a key and an authentication token. Please note the only time you have access to the authentication token is during this set up process.

**To add this library to your project, add** `#require "IBMWatson.class.nut:1.0.0"` **to the top of your agent code.**

## Class Usage

### Optional Callbacks

All requests to Watson will be made asynchonously. Any method that sends a request will have an optional callback parameter.  If a callback is provided it will be executed when the response is received. The callback function has two required parameters: *error* and *response*.  If no error was encountered the *error* parameter will be null.

### Constructor: IBMWatson(*apiKey, authToken, orgID[, version]*)
The constructor takes three required parameters: your API Key, Authentication Token, and Organiztion ID, and one optional parameter, the API version.  The default API version is "v0002".

##### Example Code:
```squirrel
const API_KEY = "<YOUR API KEY HERE>";
const AUTH_TOKEN = "<YOUR AUTH TOKEN HERE>";
const ORG_ID = "<YOUR ORG ID HERE>";

watson <- IBMWatson(API_KEY, AUTH_TOKEN, ORG_ID);
```

## Class Methods

### addDeviceType(*typeInfo[, httpHeaders][, cb]*)
The *addDeviceType()* method creates a device type within your organization.  The device type is needed for all device interractions, for example creating a device, or posting device data.  This method takes one required parameter: a table with the info to create a device type, and two optional parameters: a *httpHeaders* table and a *cb* function.

#### typeInfo Table
| key | value data type | Required | description |
| ----- | ------------ | ----------- | --------------- |
| *id* | string | Yes | The device type id is used to uniquely identify the device type (36 character limit) |
| *description* | string | No | The device type description can be used for a more descriptive way of identifying the device type |
| *classId* | string | No | Accepted values are "Device" or "Gateway", if you do not pass in this value defaults to "Device" |
| *deviceInfo* | table | No | Keys in the deviceInfo table define attributes to be used as a template for new devices that are assigned this device type. Attributes you do not define may still be edited individually on devices that are assigned this device type. |
| *metadata* | table | No | Meta data you wish to have associated with the device type |

##### Example Code:
```squirrel
typeInfo <- {"id": "EnvTail", "description" : "Electric Imp Environmental Sensor Tail"};
watson.addDeviceType(typeInfo, function(error, response) {
    if (error) server.error(error);
})
```

### getDeviceType(*typeID[, httpHeaders][, cb]*)
The *getDeviceType()* method requests the details for the device type specified.  This method takes one required parameter: the device's *typeID*, and two optional parameters: a *httpHeaders* table and a *cb* function.

##### Example Code:
```squirrel
local typeID = "EnvTail";
local typeInfo = {"id": typeID, "description" : "Electric Imp Environmental Sensor Tail"};

watson.getDeviceType(typeID, function(error, response) {
    // if device type doesn't exist create it
    if (error == watson.MISSING_RESOURCE_ERROR) {
        watson.addDeviceType(typeInfo);
    }
})
```

### addDevice(*typeID, device[, httpHeaders][, cb]*)
The *addDevice()* method creates a device of the specified device type.  This method takes two required parameters: the device's *typeID* and a table containing information about the *device*, and two optional parameters: a *httpHeaders* table and a *cb* function.

#### Device Table
| key | value data type | Required | description |
| ----- | ------------ | ----------- | --------------- |
| *deviceId* | string | Yes | The device id is used to uniquely identify the device. |
| *authToken* | string | No | Authentication token, will be generated if not supplied. |
| *deviceInfo* | table | No | See Device Info Table below for more details.  All keys in the deviceInfo table are optional.  |
| *location* | table | No | See Location Table below for more details. |
| *metadata* | table | No | Meta data you wish to have associated with the device type. |

#### Device Info Table
| key | value data type | description |
| ----- | ------------ | --------------- |
| *serialNumber* | string | The serial number of the device. |
| *manufacturer* | string | The manufacturer of the device. |
| *model* | string | The model of the device. |
| *deviceClass* | string | The class of the device. |
| *description* | string | The descriptive name of the device. |
| *fwVersion* | string | The firmware version currently known to be on the device. |
| *hwVersion* | string | The hardware version of the device. |
| *descriptiveLocation* | A descriptive location, such as a room or building number, or a geographical region. |

#### Location Table
| key | value data type | Required | description |
| ----- | ------------ | ----------- | --------------- |
| *longitude* | number | Yes | Longitude in decimal degrees using the WGS84 system. |
| *latitude* | number | Yes | Latitude in decimal degrees using the WGS84 system. |
| *elevation* | number | No | Elevation in meters using the WGS84 system. |
| *accuracy* | number | No | Accuracy of the position in meters. |
| *measuredDateTime* | string | No | Date and time of location measurement (ISO8601). |

##### Example Code:
```squirrel
local typeID = "EnvTail";
local deviceID = split(http.agenturl(), "/").pop();
device <- {"deviceId": deviceID,  "deviceInfo" : {"manufacturer" : "electric_imp", "descriptiveLocation" : "open_office_area"} }

watson.addDevice(typeID, device, function(error, response) {
    if (error) {
        server.error(error);
        return;
    }
    server.log(http.jsonencode(response.body));
})
```
### getDevice(*typeID, deviceID[, httpHeaders][, cb]*)
The *getDevice()* requests the details for the device specified.  This method takes two required parameters: the device's *typeID* and the *deviceID*, and two optional parameters: a *httpHeaders* table and a *cb* function.

##### Example Code:
```squirrel
local typeID = "EnvTail";
local deviceID = split(http.agenturl(), "/").pop();

watson.getDevice(typeID, deviceID, function(error, response) {
    if (error == watson.MISSING_RESOURCE_ERROR) {
        watson.addDevice(typeID, {"deviceId": deviceID});
    }
})
```

### updateDevice(*typeID, deviceID, deviceInfo[, httpHeaders][, cb]*)
The *updateDevice()* method updates the specified device with the info found in the *deviceInfo* table.  This method takes three required parameters: the device's *typeID*, the *deviceID*, and a table containing the updated *deviceInfo*, and two optional parameters: a *httpHeaders* table and a *cb* function.  See *Device Info Table* in *addDevice()* method description above for more details.

##### Example Code:
```squirrel
local typeID = "EnvTail";
local deviceID = split(http.agenturl(), "/").pop();
deviceInfo <- {"deviceInfo" : {"descriptiveLocation" : "reception"} };

watson.updateDevice(typeID, deviceID, deviceInfo, function(error, response) {
    if (error) {
        server.error(error);
        return;
    }
    server.log(http.jsonencode(response.body));
})
```

### deleteDevice(*typeID, deviceID[, httpHeaders][, cb]*)
The *addDevice()* method deletes the specified device.  This method takes two required parameters: the device's *typeID* and the *deviceID*, and two optional parameters: a *httpHeaders* table and a *cb* function.

##### Example Code:
```squirrel
local typeID = "EnvTail";
local deviceID = split(http.agenturl(), "/").pop();

watson.deleteDevice(typeID, deviceID, function(error, response) {
    if (error) server.error(error);
})
```

### postData(*typeID, deviceID, eventID, data[, httpHeaders][, cb]*)
The *postData()* method uploads data from the specified device.  This method takes four required parameters: the device's *typeID*, the *deviceID*, the *eventID* and the *data* table to be uploaded, and two optional parameters: a *httpHeaders* table and a *cb* function.  The *eventID* is a searchable string defined by the device that is posting data.

#### Data Table
| key | value data type | Required | description |
| ----- | ------------ | ----------- | --------------- |
| *d* | table | Yes | A table containing the data to be uploaded.  |
| *ts* | string | Yes | An ISO8601 formatted timestamp. |

Note: The message payload is limited to a maximum of 131072 bytes. Messages larger than this will be rejected.

##### Example Code:
```squirrel
local typeID = "EnvTail";
local deviceID = split(http.agenturl(), "/").pop();
local eventID = "temperature"
data <- { "d": { "temp": 24.3 },
          "ts": watson.formatTimestamp() };
watson.postData(typeID, deviceID, eventID, data, function(error, response) {
    if (error) server.error(error);
})
```

### formatTimestamp(*[epoch_timestamp]*)
The *formatTimestamp()* method returns an ISO8601 formatted timestamp.  This method take one optional parameter an *epoch_timestamp*, if nothing is passed in a timestamp for the current time will be created.

##### Example Code:
```squirrel
local ts = watson.formatTimestamp();
```

## License
The IBM Wason IoT library is licensed under [MIT License](./LICENSE).