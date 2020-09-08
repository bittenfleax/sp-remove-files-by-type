#Path to the dll files that sharepointclientcomponents_16-6906-1200_x64-en-us.msi extracts to - below is the default path
#You will need to download and install SharePoint Online Client Components SDK (https://www.microsoft.com/en-gb/download/details.aspx?id=42038)
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.dll"
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"

#-----------------------CONFIGURATION-------------------------#
#Username (email) of the user account you want to authenticate with
$siteUserName=""
#Password of the user account you want to authenticate with    
$sitePassword= ConvertTo-SecureString "" -AsPlainText -Force
#The URL of the site that the library is in e.g https://xxxxxx.sharepoint.com/sites/mysite/
$siteURL = ""
#Name of the document library
$libraryName = ""
#List of file types to delete
$fileTypesToDelete = @("tmp", "ds_store")
#-------------------------------------------------------------#

#Create our client context
$CContext = New-Object Microsoft.SharePoint.Client.ClientContext($siteURL)

#Give it credentials to use
$CContext.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($siteUserName, $sitePassword)

#Get SP list
$SPList = $CContext.Web.Lists.GetByTitle($libraryName)

#Create our query object and XML
$SPQuery = New-Object Microsoft.SharePoint.Client.CamlQuery
#Query properties:
    #Limit (how many items to get in each batch): 200
    #ViewFields (only gets these fields): ID, File_x0020_Type
    #View Scope (all files and subfolders): RecursiveAll
$SPQuery.ViewXml = "<View Scope='RecursiveAll'><RowLimit>200</RowLimit><ViewFields><FieldRef Name='ID' /><FieldRef Name='File_x0020_Type' /></ViewFields></View>"

do{
    #Get our items from the library
    $libraryItems = $SPList.GetItems($SPQuery)

    #Load our library items
    $CContext.Load($libraryItems)

    #Execute the query to fetch items
    $CContext.ExecuteQuery()

    #Update ListItemCollectionPosition with the current position
    $SPQuery.ListItemCollectionPosition = $libraryItems.ListItemCollectionPosition

    #If we have no items, break the loop
    if ($libraryItems.Count -eq 0) { Write-Host "No items to process. Going to exit..."; break }

    #Create a list to contain items we want to delete - this is because we can delete within a for loop as it altered the collection length
    $itemsToDelete = New-Object Collections.Generic.List[Object]

    for ($i = 0; $i -lt $libraryItems.Count; $i++)
    {
        #Print the item name | NOTE: This can be any of the following options: "FileLeafRef", "LinkFilenameNoMenu", "LinkFilename", "BaseName"
        #Write-Host $libraryItems[$i]["FileLeafRef"]

        #Get the file type
        $fileType = $libraryItems[$i]["File_x0020_Type"]
        
        #Check if the file type is in our "delete list"
        if ($fileTypesToDelete.Contains($fileType)){
            #Add item to our "Delete List" so we can remove this batch of items when we're out of this for loop
            $itemsToDelete.Add($libraryItems[$i])
        }
    }

    #Go through the items we want to delete
    ForEach($itemToDelete in $itemsToDelete) {
        #Notify output
        Write-Host "Deleting" $itemToDelete["File_x0020_Type"] "file! (ID:" $itemToDelete["ID"]")" -ForegroundColor Red

        #Delete the item
        $itemToDelete.DeleteObject()
    }

    #Execute our delete changes
    $CContext.ExecuteQuery()

#Loop through until the ListItemCollectionPosition is null (at the end)
} while ($null -ne $SPQuery.ListItemCollectionPosition)

#Completed notification
Write-Host "Completed processing library items!" -ForegroundColor Green

#Dispose of our client context
$CContext.Dispose()