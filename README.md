#IBM Wason IoT

## Class Usage

### Constructor: IBMWatson(*apiKey, authToken, orgID[, version]*)
The constructor takes three required parameters: your API Key, Authentication Token, and Organiztion ID, and one optional parameter, the API version.  The default API version is "v0002".

The *API Key* and *Auth Token* can be generated in the IBM Watson IoT Platform dashboard under the *Access -> API Keys* menu.  Please note, you will only have access to the *Authentication Token* when creating a new *API Key*, so you must store a copy of the token when you generate a new API Key.  The *Organiztion ID* can be found in your dashboard URL and also under *Configuration Settings*.

##### Example Code:
```squirrel
const API_KEY = "<YOUR API KEY HERE>";
const AUTH_TOKEN = "<YOUR AUTH TOKEN HERE>";
const ORG_ID = "<YOUR ORG ID HERE>";

watson <- IBMWatson(API_KEY, AUTH_TOKEN, ORG_ID);
```

## Class Methods

All requests to Watson will be made asynchonously, and methods that make requests have two optional parameters: a *headers* table and *cb* a callback function that will be exectuted when the response is received. The callback function will have one required parameter: the *response*.  Default headers for all requests contain *Authorization* and set the *Content-Type* to *application/json*.

### addDeviceType(*typeInfo[, headers][, cb]*)
The *addDeviceType()* method takes one required parameter: a table with the info to create a device type, and two optional parameters: a *headers* table and a *cb* function.

### getDeviceType(*typeID[, headers][, cb]*)
The *getDeviceType()* method takes one required parameter: the device's *typeID*, and two optional parameters: a *headers* table and a *cb* function.

### addDevice(*typeID, deviceInfo[, headers][, cb]*)
The *addDevice()* method takes two required parameters: the device's *typeID* and a table containing the *deviceInfo*, and two optional parameters: a *headers* table and a *cb* function.

### updateDevice(*typeID, deviceID, deviceInfo[, headers][, cb]*)
The *updateDevice()* method takes three required parameters: the device's *typeID*, the *deviceID*, and a table containing the updated *deviceInfo*, and two optional parameters: a *headers* table and a *cb* function.

### deleteDevice(*typeID, deviceID[, headers][, cb]*)
The *addDevice()* method takes two required parameters: the device's *typeID* and the *deviceID*, and two optional parameters: a *headers* table and a *cb* function.

### postData(*typeID, deviceID, eventID, data[, headers][, cb]*)
The message payload is limited to a maximum of 131072 bytes. Messages larger than this will be rejected.

### formatTimestamp(*[epoch_timestamp]*)

## License
The IBM Wason IoT library is licensed under [MIT License](./LICENSE).