## DreamFactoryEZ

This project is primarily a rewrite of the iOS Sample app for DreamFactory. That app is
outdated and not complete. It also does not seem very standard. This replacement uses the
same demo backend and requires the same setup at that one although I've committed this
code with the keys for my dev DreamFactory backend.
![Split Examples](./Split3Ex.png)

### Features
 
 - Generic REST client: This project has a somewhat generic RESTClient only customized
 for DreamFactory specifics where needed.
 - A DataAccess layer that knows about the domain data and has an interface for the needed
 application features.
 - Demonstration of simplified REST call chaining. Deleting a contact results in 3 async
 calls to the server, but this is all hidden within the RESTClient layer.
 - Automatic re-authentication of expired token.
 - Does not use any 3rd party libraries like AlamoFire or SwiftyJSON. I like an use those
 libraries, but wanted to show that they are not required and follow the minimalistic model
 of the existing demo app.
 - Error handling for all API errors.
 
### Changes from DreamFactory demo
  
 - Display, flow, presentation completely changed.
 - Internal design somewhat similar, but more clear boundaries between UI, App, and Server
 logic.
 - Updated for Swift 2.2 and all deprecated methods removed.
  
### Possible Enhancements

 - Contact image features integrating with DreamFactory were not completed.
 - No client side validation.
 - Advanced user registration with both email and OAuth providers (Facebook, Twitter) would
 be great.
 
 Let me know what you think mailto:eje@geoderanch.com
