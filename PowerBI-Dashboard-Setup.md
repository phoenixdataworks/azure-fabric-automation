# Azure Fabric Capacity Automation - Power BI Dashboard Setup Guide

This guide provides step-by-step instructions for setting up the Power BI dashboard and Power Automate flows for the Azure Fabric Capacity Automation solution.

## Prerequisites

Before you begin, ensure you have:

- Completed the [Azure Automation Setup Guide](./Setup-Guide.md)
- The webhook URLs for the runbooks (from the FabricCapacityWebhooks.json file)
- Power BI Desktop installed
- A Power BI Pro or Premium license
- Access to Power Automate (Microsoft Flow)

## Setup Steps

### 1. Create the Power BI Dataset

First, we'll create a Power BI dataset that will store the Fabric capacity status information:

1. Open Power BI Desktop
2. Create a new blank report
3. Click on "Enter Data" in the Home tab
4. Create a table named "FabricCapacityStatus" with the following columns:
   - CapacityName (Text)
   - Status (Text)
   - LastUpdated (DateTime)
   - LastStarted (DateTime)
   - LastStopped (DateTime)
   - SubscriptionId (Text)
   - ResourceGroup (Text)
   - Region (Text)
   - SKU (Text)
   - AutomationAccount (Text)

5. Add a sample row with the following data:
   - CapacityName: Your Fabric capacity name
   - Status: "Unknown"
   - LastUpdated: Current date and time
   - LastStarted: Leave blank
   - LastStopped: Leave blank
   - SubscriptionId: Your subscription ID
   - ResourceGroup: Your resource group name
   - Region: Your capacity region
   - SKU: Your capacity SKU (e.g., "F2")
   - AutomationAccount: Your automation account name

6. Click "Load" to create the table

7. Create another table named "CapacityActions" with the following columns:
   - ActionType (Text)
   - ActionTime (DateTime)
   - Status (Text)
   - User (Text)
   - Details (Text)

8. Add a sample row with the following data:
   - ActionType: "Check Status"
   - ActionTime: Current date and time
   - Status: "Success"
   - User: Your username
   - Details: "Initial setup"

9. Click "Load" to create the table

10. Save the Power BI Desktop file as "FabricCapacityDashboard.pbix"

### 2. Create the Power BI Dashboard

Now, let's create a dashboard to display the Fabric capacity status and provide controls for starting and stopping the capacity:

1. In Power BI Desktop, create a new page named "Dashboard"

2. Add a card visual to display the current status:
   - Drag the "Status" field from the "FabricCapacityStatus" table to the card
   - Format the card to make it prominent
   - Add conditional formatting to show different colors based on the status:
     - "Running" = Green
     - "Paused" = Red
     - "Unknown" = Gray
     - "Starting" = Yellow
     - "Stopping" = Yellow

3. Add a card visual to display the last updated time:
   - Drag the "LastUpdated" field from the "FabricCapacityStatus" table to the card
   - Format the card to show the date and time

4. Add a table visual to show the capacity details:
   - Drag the following fields from the "FabricCapacityStatus" table to the table:
     - CapacityName
     - SubscriptionId
     - ResourceGroup
     - Region
     - SKU
   - Format the table to make it easy to read

5. Add a table visual to show the action history:
   - Drag all fields from the "CapacityActions" table to the table
   - Sort by "ActionTime" in descending order
   - Format the table to make it easy to read

6. Add buttons for starting and stopping the capacity:
   - Add a button visual for "Start Capacity"
   - Add a button visual for "Stop Capacity"
   - Add a button visual for "Refresh Status"
   - Format the buttons to make them prominent and easy to click

7. Add a title and any additional information or instructions

8. Save the Power BI Desktop file

### 3. Publish the Power BI Dashboard

Publish the dashboard to the Power BI service:

1. In Power BI Desktop, click on "Publish" in the Home tab
2. Sign in to your Power BI account if prompted
3. Select a workspace to publish to
4. Click "Publish"
5. Once published, open the report in the Power BI service
6. Pin the visuals to a dashboard if desired
7. Share the dashboard with users who need access

### 4. Create Power Automate Flows

Now, let's create Power Automate flows to connect the Power BI dashboard to the Azure Automation webhooks:

#### 4.1. Create the "Start Capacity" Flow

1. Go to [Power Automate](https://flow.microsoft.com)
2. Sign in with your Microsoft account
3. Click on "Create" > "Instant cloud flow"
4. Name the flow "Start Fabric Capacity"
5. Select the "PowerApps" trigger and click "Create"
6. In the flow editor, add the following actions:

   a. **Initialize variable** action:
      - Name: "WebhookURL"
      - Type: "String"
      - Value: Paste the Start webhook URL from the FabricCapacityWebhooks.json file

   b. **HTTP** action:
      - Method: "POST"
      - URI: Use the "WebhookURL" variable
      - Headers: Add "Content-Type" with value "application/json"
      - Body: `{}`

   c. **Parse JSON** action:
      - Content: Body from the HTTP action
      - Schema: Use the following schema or generate it from a sample output:
      ```json
      {
        "type": "object",
        "properties": {
          "CapacityName": { "type": "string" },
          "Status": { "type": "string" },
          "SubscriptionId": { "type": "string" },
          "ResourceGroup": { "type": "string" },
          "Region": { "type": "string" },
          "SKU": { "type": "string" },
          "LastUpdated": { "type": "string" }
        }
      }
      ```

   d. **Add rows to a dataset** action (for updating the status):
      - Workspace: Select your Power BI workspace
      - Dataset: Select the "FabricCapacityDashboard" dataset
      - Table: "FabricCapacityStatus"
      - Rows: 
      ```json
      {
        "CapacityName": "@{body('Parse_JSON').CapacityName}",
        "Status": "@{body('Parse_JSON').Status}",
        "LastUpdated": "@{body('Parse_JSON').LastUpdated}",
        "LastStarted": "@{utcNow()}",
        "SubscriptionId": "@{body('Parse_JSON').SubscriptionId}",
        "ResourceGroup": "@{body('Parse_JSON').ResourceGroup}",
        "Region": "@{body('Parse_JSON').Region}",
        "SKU": "@{body('Parse_JSON').SKU}",
        "AutomationAccount": "FabricCapacityAutomation"
      }
      ```

   e. **Add rows to a dataset** action (for logging the action):
      - Workspace: Select your Power BI workspace
      - Dataset: Select the "FabricCapacityDashboard" dataset
      - Table: "CapacityActions"
      - Rows: 
      ```json
      {
        "ActionType": "Start Capacity",
        "ActionTime": "@{utcNow()}",
        "Status": "@{if(equals(body('Parse_JSON').Status, 'Running'), 'Success', 'Failed')}",
        "User": "@{user().email}",
        "Details": "@{body('Parse_JSON').Status}"
      }
      ```

7. Save the flow

#### 4.2. Create the "Stop Capacity" Flow

1. Go to [Power Automate](https://flow.microsoft.com)
2. Click on "Create" > "Instant cloud flow"
3. Name the flow "Stop Fabric Capacity"
4. Select the "PowerApps" trigger and click "Create"
5. In the flow editor, add the following actions:

   a. **Initialize variable** action:
      - Name: "WebhookURL"
      - Type: "String"
      - Value: Paste the Stop webhook URL from the FabricCapacityWebhooks.json file

   b. **HTTP** action:
      - Method: "POST"
      - URI: Use the "WebhookURL" variable
      - Headers: Add "Content-Type" with value "application/json"
      - Body: `{}`

   c. **Parse JSON** action:
      - Content: Body from the HTTP action
      - Schema: Use the same schema as in the "Start Capacity" flow

   d. **Add rows to a dataset** action (for updating the status):
      - Workspace: Select your Power BI workspace
      - Dataset: Select the "FabricCapacityDashboard" dataset
      - Table: "FabricCapacityStatus"
      - Rows: 
      ```json
      {
        "CapacityName": "@{body('Parse_JSON').CapacityName}",
        "Status": "@{body('Parse_JSON').Status}",
        "LastUpdated": "@{body('Parse_JSON').LastUpdated}",
        "LastStopped": "@{utcNow()}",
        "SubscriptionId": "@{body('Parse_JSON').SubscriptionId}",
        "ResourceGroup": "@{body('Parse_JSON').ResourceGroup}",
        "Region": "@{body('Parse_JSON').Region}",
        "SKU": "@{body('Parse_JSON').SKU}",
        "AutomationAccount": "FabricCapacityAutomation"
      }
      ```

   e. **Add rows to a dataset** action (for logging the action):
      - Workspace: Select your Power BI workspace
      - Dataset: Select the "FabricCapacityDashboard" dataset
      - Table: "CapacityActions"
      - Rows: 
      ```json
      {
        "ActionType": "Stop Capacity",
        "ActionTime": "@{utcNow()}",
        "Status": "@{if(equals(body('Parse_JSON').Status, 'Paused'), 'Success', 'Failed')}",
        "User": "@{user().email}",
        "Details": "@{body('Parse_JSON').Status}"
      }
      ```

6. Save the flow

#### 4.3. Create the "Get Capacity Status" Flow

1. Go to [Power Automate](https://flow.microsoft.com)
2. Click on "Create" > "Scheduled cloud flow"
3. Name the flow "Get Fabric Capacity Status"
4. Set the schedule to run every 15 minutes (or your preferred interval)
5. Click "Create"
6. In the flow editor, add the following actions:

   a. **Initialize variable** action:
      - Name: "WebhookURL"
      - Type: "String"
      - Value: Paste the Status webhook URL from the FabricCapacityWebhooks.json file

   b. **HTTP** action:
      - Method: "POST"
      - URI: Use the "WebhookURL" variable
      - Headers: Add "Content-Type" with value "application/json"
      - Body: `{}`

   c. **Parse JSON** action:
      - Content: Body from the HTTP action
      - Schema: Use the same schema as in the "Start Capacity" flow

   d. **Add rows to a dataset** action (for updating the status):
      - Workspace: Select your Power BI workspace
      - Dataset: Select the "FabricCapacityDashboard" dataset
      - Table: "FabricCapacityStatus"
      - Rows: 
      ```json
      {
        "CapacityName": "@{body('Parse_JSON').CapacityName}",
        "Status": "@{body('Parse_JSON').Status}",
        "LastUpdated": "@{body('Parse_JSON').LastUpdated}",
        "SubscriptionId": "@{body('Parse_JSON').SubscriptionId}",
        "ResourceGroup": "@{body('Parse_JSON').ResourceGroup}",
        "Region": "@{body('Parse_JSON').Region}",
        "SKU": "@{body('Parse_JSON').SKU}",
        "AutomationAccount": "FabricCapacityAutomation"
      }
      ```

   e. **Add rows to a dataset** action (for logging the action):
      - Workspace: Select your Power BI workspace
      - Dataset: Select the "FabricCapacityDashboard" dataset
      - Table: "CapacityActions"
      - Rows: 
      ```json
      {
        "ActionType": "Check Status",
        "ActionTime": "@{utcNow()}",
        "Status": "Success",
        "User": "System",
        "Details": "@{body('Parse_JSON').Status}"
      }
      ```

7. Save the flow

### 5. Connect the Power BI Dashboard to the Power Automate Flows

Now, let's connect the buttons in the Power BI dashboard to the Power Automate flows:

1. Go to the Power BI service and open the "FabricCapacityDashboard" report
2. Select the "Start Capacity" button
3. In the Visualizations pane, under the Format section, expand the Action section
4. Set the Type to "Power Automate"
5. Select the "Start Fabric Capacity" flow
6. Repeat steps 2-5 for the "Stop Capacity" button, selecting the "Stop Fabric Capacity" flow
7. For the "Refresh Status" button, set the action to refresh the dataset

### 6. Test the Solution

Test the solution to ensure everything is working correctly:

1. Open the Power BI dashboard
2. Click the "Refresh Status" button to get the current status
3. If the capacity is paused, click the "Start Capacity" button to start it
4. Wait for the status to update (you may need to refresh the dashboard)
5. Once the capacity is running, click the "Stop Capacity" button to stop it
6. Wait for the status to update
7. Check the action history to verify that the actions were logged correctly

## Customization Options

### Adding Multiple Capacities

To support multiple Fabric capacities, you can:

1. Modify the dataset to include a capacity identifier column
2. Create separate flows for each capacity, or modify the flows to accept a capacity identifier parameter
3. Update the dashboard to include filters or tabs for different capacities

### Adding Notifications

To add notifications when the capacity status changes:

1. Modify the "Get Capacity Status" flow to include a condition that checks if the status has changed
2. Add an action to send an email, Teams message, or other notification if the status has changed

### Adding Cost Tracking

To track the cost of running the Fabric capacity:

1. Add columns to the "FabricCapacityStatus" table for cost-related information
2. Modify the flows to calculate and update the cost information
3. Add visuals to the dashboard to display the cost information

## Troubleshooting

### Power BI Dataset Issues

If you encounter issues with the Power BI dataset:

1. Check that the dataset schema matches the expected schema
2. Verify that the Power Automate flows have the correct permissions to update the dataset
3. Try refreshing the dataset manually

### Power Automate Flow Issues

If you encounter issues with the Power Automate flows:

1. Check the flow run history for error messages
2. Verify that the webhook URLs are correct
3. Ensure that the JSON parsing is working correctly
4. Check that the Power BI dataset actions are configured correctly

### Button Action Issues

If the buttons in the Power BI dashboard are not working:

1. Check that the buttons are configured to use the correct Power Automate flows
2. Verify that the flows are published and enabled
3. Ensure that you have the necessary permissions to run the flows

## Next Steps

After completing the Power BI dashboard setup, you can:

1. Share the dashboard with users who need to control the Fabric capacity
2. Set up alerts for capacity status changes
3. Extend the solution to support additional features or capacities

## Additional Resources

- [Power BI Documentation](https://docs.microsoft.com/en-us/power-bi/)
- [Power Automate Documentation](https://docs.microsoft.com/en-us/power-automate/)
- [Microsoft Fabric Documentation](https://docs.microsoft.com/en-us/fabric/)
