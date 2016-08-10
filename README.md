#IBM Wason IoT

The IBMWatson library allows you to easily integrate your agent code with [IBM&reg; Watson&trade; IoT Platform](https://docs.internetofthings.ibmcloud.com/getting_started/quickstart/index.html). This library provides an easy way to access a number of the IBM Watson IoT Platform HTTP REST API endpoints. Click [here](https://docs.internetofthings.ibmcloud.com/swagger/v0002.html#/) for the full documentation of the API.

### Watson Setup

To use this library you will need to register an organization on the Watson IoT platform. After registering, you will be provided with a six-character organization ID. You will also need to generate an API key, and during its generation you will be presented with an authentication token. Please note that the only time you have access to this authentication token is during this set-up process. You will need the API key, authentication token and organization ID to instantiate IBMWatson objects in your agent code.

**To add this library to your project, add** `#require "IBMWatson.class.nut:1.0.0"` **to the top of your agent code.**

## Class Usage

### Optional Callbacks

All requests to Watson will be made asynchonously. Any method that sends a request can take an optional callback parameter. If a callback is provided, it will be executed when the response is received. The callback function has two required parameters: *error* and *response*. If no error was encountered, the *error* parameter will be null.

### Constructor: IBMWatson(*apiKey, authToken, orgID[, version]*)

The constructor takes three required parameters: your API key, authentication token and organization ID. There is also  one optional parameter, the API version, passed as a string. The default API version is "v0002".

##### Example Code:
```squirrel
#require "IBMWatson.class.nut:1.0.0"

const API_KEY = "<YOUR API KEY>";
const AUTH_TOKEN = "<YOUR AUTHENTICATION TOKEN>";
const ORG_ID = "<YOUR ORGANIZATION ID>";

watson <- IBMWatson(API_KEY, AUTH_TOKEN, ORG_ID);
```

## Class Methods

### addDeviceType(*typeInfo[, httpHeaders][, callback]*)

The *addDeviceType()* method creates a device type within your organization. The device type is needed for all device interractions, whether you are creating a device or posting device data. This method takes one required parameter: a table with the information required to create a device type. It has two optional parameters: an *httpHeaders* table and a *callback* function.

#### typeInfo Table

| Key | Value data type | Required? | Description |
| --- | --------------- | --------- | ----------- |
| *id* | String | Yes | The device type ID is used to uniquely identify the device type (36-character limit) |
| *description* | String | No | The device type description can be used for a more descriptive way of identifying the device type |
| *classId* | String | No | Accepted values are `"Device"` or `"Gateway"`. If you do not pass in this value, it defaults to `"Device"` |
| *deviceInfo* | Table | No | Keys in the *deviceInfo* table define attributes to be used as a template for new devices that are assigned this device type. Attributes you do not define may still be edited individually on devices that are assigned this device type |
| *metadata* | Table | No | Metadata you wish to have associated with the device type |

#### Example

```squirrel
typeInfo <- { "id": "EnvTail", 
              "description" : "Electric Imp Environmental Sensor Tail" };

watson.addDeviceType(typeInfo, function(error, response) {
    if (error) server.error(error);
})
```

### getDeviceType(*typeID[, httpHeaders][, callback]*)

The *getDeviceType()* method requests the details for the device type specified. This method takes one required parameter, the device’s *typeID*, and two optional parameters: an *httpHeaders* table and a *callback* function.

#### Example

```squirrel
local typeID = "EnvTail";
local typeInfo = { "id": typeID,
                   "description" : "Electric Imp Environmental Sensor Tail" };

watson.getDeviceType(typeID, function(error, response) {
    // If device type doesn't exist, create it
    if (error == watson.MISSING_RESOURCE_ERROR) {
        watson.addDeviceType(typeInfo);
    }
})
```

### addDevice(*typeID, device[, httpHeaders][, callback]*)

The *addDevice()* method creates a device of the specified device type. This method takes two required parameters: the device’s *typeID* and a table containing information about the *device*. It has two optional parameters: an *httpHeaders* table and a *callback* function.

#### Device Table

| Key | Value data type | Required? | Description |
| ----| --------------- | --------- | ----------- |
| *deviceId* | String | Yes | The device ID is used to uniquely identify the device |
| *authToken* | String | No | Authentication token. This will be generated if not supplied |
| *deviceInfo* | Table | No | See ‘DeviceInfo Table’, below, for more details. All keys in the *deviceInfo* table are optional |
| *location* | Table | No | See ‘Location Table’ below for more details |
| *metadata* | Table | No | Metadata you wish to have associated with the device type |

#### DeviceInfo Table

| Key | Value data type | Description |
| --- | --------------- | ----------- |
| *serialNumber* | String | The serial number of the device |
| *manufacturer* | String | The manufacturer of the device |
| *model* | String | The model of the device |
| *deviceClass* | String | The class of the device |
| *description* | String | The descriptive name of the device |
| *fwVersion* | String | The firmware version currently known to be on the device |
| *hwVersion* | String | The hardware version of the device |
| *descriptiveLocation* | Table | A descriptive location, such as a room or building number, or a geographical region |

#### Location Table

| Key | Value data type | Required? | Description |
| --- | --------------- | --------- | ----------- |
| *longitude* | Number | Yes | Longitude in decimal degrees using the WGS84 system |
| *latitude* | Number | Yes | Latitude in decimal degrees using the WGS84 system |
| *elevation* | Number | No | Elevation in meters using the WGS84 system |
| *accuracy* | Number | No | Accuracy of the position in meters |
| *measuredDateTime* | String | No | Date and time of location measurement (ISO8601) |

#### Example

```squirrel
local typeID = "EnvTail";
local deviceID = split(http.agenturl(), "/").pop();
device <- { "deviceId": deviceID,
            "deviceInfo" : { "manufacturer" : "electric_imp", 
                             "descriptiveLocation" : "open_office_area" }};

watson.addDevice(typeID, device, function(error, response) {
    if (error) {
        server.error(error);
        return;
    }
    
    server.log(http.jsonencode(response.body));
})
```

### getDevice(*typeID, deviceID[, httpHeaders][, callback]*)

The *getDevice()* requests the details for the device specified. This method takes two required parameters: the device’s *typeID* and its *deviceID*. It also has two optional parameters: an *httpHeaders* table and a *callback* function.

#### Example
```squirrel
local typeID = "EnvTail";
local deviceID = split(http.agenturl(), "/").pop();

watson.getDevice(typeID, deviceID, function(error, response) {
    if (error == watson.MISSING_RESOURCE_ERROR) {
        watson.addDevice(typeID, { "deviceId": deviceID });
    }
})
```

### updateDevice(*typeID, deviceID, deviceInfo[, httpHeaders][, callback]*)

The *updateDevice()* method updates the specified device with the information found in the *deviceInfo* table, above.  This method takes three required parameters: the device’s *typeID*, its *deviceID* and a table containing the updated *deviceInfo*. It can also take two optional parameters: an *httpHeaders* table and a *callback* function.

#### Example

```squirrel
local typeID = "EnvTail";
local deviceID = split(http.agenturl(), "/").pop();
deviceInfo <- { "deviceInfo" : { "descriptiveLocation" : "reception" }};

watson.updateDevice(typeID, deviceID, deviceInfo, function(error, response) {
    if (error) {
        server.error(error);
        return;
    }
    
    server.log(http.jsonencode(response.body));
})
```

### deleteDevice(*typeID, deviceID[, httpHeaders][, callback]*)

The *addDevice()* method deletes the specified device. This method takes two required parameters: the device’s *typeID* and its *deviceID*. It can also take two optional parameters: an *httpHeaders* table and a *callback* function.

#### Example

```squirrel
local typeID = "EnvTail";
local deviceID = split(http.agenturl(), "/").pop();

watson.deleteDevice(typeID, deviceID, function(error, response) {
    if (error) server.error(error);
})
```

### postData(*typeID, deviceID, eventID, data[, httpHeaders][, cb]*)

The *postData()* method uploads data from the specified device. This method takes four required parameters: the device’s *typeID*, its *deviceID*, an *eventID* and the *data* to be uploaded. It also takes two optional parameters: an *httpHeaders* table and a *callback* function.

The *eventID* is a searchable string defined by the device that is posting data. The data itself is passed as a table:

#### Data Table

| Key | Value data type | Required? | Description |
| --- | --------------- | --------- | ----------- |
| *d* | Table | Yes | A table containing the data to be uploaded |
| *ts* | String | Yes | An ISO8601-format timestamp (see *formatTimestamp()*, below) |

**Note** The message payload is limited to a maximum of 131072 bytes. Messages larger than this will be rejected.

#### Example

```squirrel
local typeID = "EnvTail";
local deviceID = split(http.agenturl(), "/").pop();
local eventID = "temperature";
data <- { "d": { "temp": 24.3 },
          "ts": watson.formatTimestamp() };

watson.postData(typeID, deviceID, eventID, data, function(error, response) {
    if (error) server.error(error);
})
```

### formatTimestamp(*[epoch_timestamp]*)

The *formatTimestamp()* method returns an ISO8601-format timestamp. This method take one optional parameter: an *epoch_timestamp*. If nothing is passed in, a timestamp for the current time will be created.

#### Example

```squirrel
local ts = watson.formatTimestamp();
```

## License

The IBMWason library is licensed under [MIT License](./LICENSE).
