#Electric Imp Smart Refrigerator

Create a connected refrigerator using an Electric Imp and the IBM Watson IoT platform.

## Overview
Skill Level: Beginner

Below are detailed steps on how to connect an Electric Imp with environmental sensors to the Watson IoT Platform in order to visualize and monitor your refrigerator in real time.

## Ingredients

 1. Your WIFI *network name* and *password*
 2. A computer with a web browser
 3. Smartphone with the Electric Imp app ([iOS](https://itunes.apple.com/us/app/electric-imp/id547133856) or [Android](https://play.google.com/store/apps/details?id=com.electricimp.electricimp))
 4. A free [Electric Imp developer account](https://ide.electricimp.com/login)
 5. A [IBM Bluemix account](https://console.ng.bluemix.net/registration/)
 6. An Electric Imp Explorer kit - to purchase email watsonIoT@electricimp.com
 7. Three AA batteries

## Step-by-step

### Step 1 - What is demonstrated in this example?
Use an Electric Imp to collect temperature, humidity, accelerometer and light sensor data.  Analyze the sensor data to determine if your refrigerator compressor is working properly and to track if your refrigerator door has been left open.  Upload data to the Watson IoT platform to monitor and visualize your refrigerator in real time.

### Step 2 - Create a Watson IoT Service

Open [Bluemix IoT](https://new-console.ng.bluemix.net/catalog/?category=iot) page in your web browser and log into your Bluemix account.

**Note:** If you have not created an organization, a pop up will walk you through the steps for creating an organization and space. When you are done click [this link](https://new-console.ng.bluemix.net/catalog/?category=iot) to get back to Bluemix IoT page.

On the [Bluemix IoT](https://new-console.ng.bluemix.net/catalog/?category=iot) page select **Internet of Things Platform** to open the form to create a project.

![Bluemix IoT page](http://i.imgur.com/pd5LhfS.png)

To *Create a Project* enter the following information

1. *Service Name*: leave default or give it an identifing name like *Electric Imp Smart Refrigerator*
2. *Connected to*: leave set to **Leave Unbound**
3. *Pricing Plan*: you can leave set to **Free**
4. Scroll to the bottom and click **Create**

Next we need to launch the service dashboard, so after *creating a project* click **Launch dashboard** button.

![Bluemix Project page](http://i.imgur.com/4zBY0Fi.png)

Once you are in the service dashboard, there are 3 items you need to copy down.  These will need to be pasted into the code during **Step 4**, your **Organization ID**, **API Key**, and **Authentication Token**.

1. Locating your **Organization ID**

  Select *Settings* tab in the sidebar
  ![Settings Sidebar](http://i.imgur.com/pKOXxmD.png)

  Under *General* make a note or you **Organization ID**
  ![Org ID](http://i.imgur.com/HLRfVOQ.png)

2. Locating your **API Key** & **Authentication Token**

  Select *Access* tab in the sidebar
  ![Settings Sidebar](http://i.imgur.com/sZeEF8B.png)

  Click **API Keys** tab, then **+ Generate API Key** button
  ![API Key Tab](http://i.imgur.com/AOhHyU1.png)

  Make note of your **API Key** & **Authentication Token**
  ![Generate API Key](http://i.imgur.com/I3Ta14z.png)
  *Note*: The **Authentication Token** can only be viewed when generating an API Key, you must store a copy of the **Authentication Token** before leaving this screen.

  When you have copied down your key and token, click **Finish** to create keys.

### Step 3 - Connect your Electric Imp to the Internet

#### Set Up Hardware

1. Plug the Imp001 into the Explorer Kit Board
3. Power up your Imp with the AA batteries.

![Explorer Kit](http://i.imgur.com/6JssX74.png)

When the imp is first powered on it will blink amber/red.

#### Electric Imp BlinkUp

Use the Electric Imp mobile app to BlinkUp your device

1. In the app log into your Electric Imp developer account
2. Enter your WIFI credentials
3. Follow the instructions in the app to BlinkUp your device

When BlinkUp is successful the imp will blink green and the app will show you the device's unique ID.

<img src="http://i.imgur.com/rljkSnI.png" width="250">

For more information on BlinkUp visit the Electric Imp [Dev Center](https://electricimp.com/docs/gettingstarted/blinkup/).

### Step 4 - Connect your Electric Imp to Watson IoT

In your web browser log into the [Electric Imp IDE](https://ide.electricimp.com/login) using your Electric Imp developer account.

Click the **+** button to create a new model

![Empty IDE](http://i.imgur.com/Ui7w8eG.png)

In the pop-up enter the following information:

1. A name for your code model (ie Smart Refrigerator)
2. Select the checkbox next to your device ID, this assigns your device to this code model
3. Click **Create Model** button

To get you started we have some example code for an IBM Watson Smart Refrigerator.  This code can be found in Electric Imp's [IBMWatson Github repository](https://github.com/electricimp/IBMWatson/tree/master/Examples/SmartRefrigerator).

Copy and paste the IBM Watson Smart Refrigerator example code into the agent and device coding windows.  The agent.nut file should go in the agent coding window, the device.nut file in the device coding window.

![IDE code windows](http://i.imgur.com/yiCmQZu.png)

Scroll the the bottom of the agent code to find *Watson API Auth Keys* variables. Enter your **API Key**, **Authentication Token**, and **Organization ID** from **Step 2** into the corresponding variables.

Click **Build and Run** to save and launch the code

![IDE with code](http://i.imgur.com/zlJaIaw.png)


### 5.  Create Visualizations In the Watson IoT Dashboard

#### Create Board

Open up your IBM Watson IoT service dashboard, use the sidebar to navigate to **Boards**. Then click **+ Create New Board** button.
![Boards Sidebar](http://i.imgur.com/qaratc1.png)

1. Enter Board Name (ie Refrigerator Monitor)
2. Enter a Description (optional)
3. Select **Make this board my landing page**
4. Select **Favorite**
5. Click **Next**
6. Click **Create**

Select the Board you just created from **Your Boards** section.
![Select Card](http://i.imgur.com/IbPVmFX.png)

**Note**: To complete this step we need a device to be configured in Watson. An Imp running the example code will create a device programatically, so if you have not completed **Step 4 - Connect your Electric Imp to Watson**, please do so before continuing.

#### Create Cards

We are going to add a couple different types of cards to our board, a *realitime chart* to track the temperature and humidity of the refrigerator, two *gauges* to show the current temperature and humidity, and a *value* card to show the current status of the refrigerator door.

To add new cards follow the step by step instructions below.

![New Card](http://i.imgur.com/nhfPDNW.png)


###### Realtime chart
Click **+Add New Card** button

1. Scoll down to **Devices** section and select **Realtime Chart**
2. Select your device and click **Next**
3. Click **Connect new data set**
  - *Name* : Enter **Temperature**
  - *Event* : select **RefrigeratorMonitor**
  - *Property* : select **temperature**
  - *Type* : select **Number**
  - *Unit* : select **°C**
4. Click **Connect new data set**
  - *Name* : Enter **Humidity**
  - *Event* : select **RefrigeratorMonitor**
  - *Property* : select **humidity**
  - *Type* : select **Number**
  - *Unit* : select **%**
5. Click **Next**
6. Under *Settings* select **XL** and click **Next**
7. Enter a *Title* and *Descrtiption* (optional)
8. Select a *Color scheme* (optional)
9. Click **Submit**

###### Temperature gauge
Click **+Add New Card** button

1. Scoll down to **Devices** section click *show more* and select **Gauge**
2. Select your device and click **Next**
3. Click **Connect new data set**
  - *Name* : Enter **Temperature**
  - *Event* : select **RefrigeratorMonitor**
  - *Property* : select **temperature**
  - *Type* : select **Number**
  - *Unit* : select **°C**
4. Click **Next**
5. Under *Settings* select **M** and click **Next**
6. Enter a *Title* and *Descrtiption* (optional)
7. Select a *Color scheme* (optional)
8. Click **Submit**

###### Humidity gauge
Click **+Add New Card** button. Then repeat *Create Temperature gauge* steps, but replace step 3 with step below.

3. Click **Connect new data set**
  - *Name* : Enter **Humidity**
  - *Event* : select **RefrigeratorMonitor**
  - *Property* : select **humidity**
  - *Type* : select **Number**
  - *Unit* : select **%**

###### Door gauge
Click **+Add New Card** button

1. Scoll down to **Devices** section click *show more* and select **Value**
2. Select your device and click **Next**
3. Click **Connect new data set**
  - *Name* : Enter **Door Status**
  - *Event* : select **RefrigeratorMonitor**
  - *Property* : select **door**
  - *Type* : select **text**
4. Click **Next**
5. Under *Settings* select **M** and click **Next**
6. Enter a *Title* and *Descrtiption* (optional)
7. Select a *Color scheme* (optional)
8. Click **Submit**

Your final dashboard should look like this:
![Dashboard](http://i.imgur.com/jyUMQJC.png)

### 6.  Install the Imp in your Refrigerator

Open your refrigerator and place the Imp on a shelf in the door.

![Imp In Fridge](http://i.imgur.com/z5llZBg.png)

### 7.  Optional Improvements

Your refrigerator is now connected to the internet. As you begin to gather data for your refrigerator you should adjust the static variables in your device SmartFridgeApp class to further customize your integration.

* Adjust the temperature, humidity, and lighting thresholds to optimize for your frigde
* Adjust the reading and reporting times to optimize power usage