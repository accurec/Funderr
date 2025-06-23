## Spec (this readme is still work in progress)

This is a multi campaign crowdfunding dApp. People can create campaigns and then others will contribute.
When the campaign is created, the deadline is also set for it. Contributors cannot withdraw unless two conditions are met:
1) campaign has not reached the goal; 2) campaign deadline has passed. Once the campaign has reached the goal and the deadline
has passed, then the creator can withdraw contributions. If after deadline has passed and campaign has reached the goal, but
the creator has not withdrawn within a month, the contributors can withdraw their funds - this will allow to prevent stale
campaigns existence.

The barebones React + ethers.js frontend that can be used to explore all dApp functions can be found here: [FunderrFrontend](https://github.com/accurec/FunderrFrontend).

## TODO

1) Add the image URL fields so that it is possible to have images attached to campaigns. Pass URLs as part of create campaign call.