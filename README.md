# Nexus Cleaner

### Clean your unused Docker Images

###### Script Name:  

**cleaner.sh**

###### Parameters:

* **--nexus-user** : Admin Username
* **--nexus-passwd** : Admin Username Passwd
* **--nexus-url** : Nexus URL
* **--gitlab-url** : Gitlab URL
* **--gitlab-token**  Gitlab Token
* **--nexus-keep-tags** TAG Names to keep (Do not delete these tags) Seperated with space for multiple tags
  * Example :  STG1 STG2
  * "latest" tag is already in protection. Do not need add
* **--nexus-filter-images** RegEx for Image Name to delete
  * ".*" : All Images
  * ^myproject-.* : Starting with "myproject"

##### Using Example

```
  ./cleaner.sh \
    --nexus-user="admin" \
    --nexus-passwd="admnin-passwd" \
    --nexus-url="https://nexus.domain.com" \
    --gitlab-url="https://gitlab.domain.com" \
    --gitlab-token="78Ybf-edT67-TYoh56" \
    --nexus-keep-tags="STG-1 STG-2" \
    --nexus-filter-images="^myproject-.*$"
```