![JustTweak Banner](./img/just_tweak_banner.png)

# JustTweak

[![Build Status](https://travis-ci.org/justeat/JustTweak.svg?branch=master)](https://travis-ci.org/justeat/JustTweak)
[![Version](https://img.shields.io/cocoapods/v/JustTweak.svg?style=flat)](http://cocoapods.org/pods/JustTweak)
[![License](https://img.shields.io/cocoapods/l/JustTweak.svg?style=flat)](http://cocoapods.org/pods/JustTweak)
[![Platform](https://img.shields.io/cocoapods/p/JustTweak.svg?style=flat)](http://cocoapods.org/pods/JustTweak)

JustTweak is a feature flagging framework for iOS apps.
It provides a simple facade interface interacting with multiple tweak providers that are queried respecting a given priority.
Tweaks represent flags used to drive decisions in the client code. 

With JustTweak you can achieve the following:

- use a JSON file to provide the default values for feature flagging 
- use a number of remote tweak providers such as Firebase and Optmizely to run A/B tests and feature flagging  
- enable, disable, and customize features locally at runtime
- provide a dedicated UI for customization (this comes particularly handy for feature that are under development to showcase it to stakeholders)


## Installation

JustTweak is available through [CocoaPods](http://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod "JustTweak"
```

## Implementation

### Integration

- Define a `LocalTweakProvider` JSON file including your features. Refer to `LocalTweaks_example.json` for a starting point.
- Configure the stack

To configure the stack, you have two options: 

- implement the stack manually
- leverage the code generator tool

#### Manual integration

- Configure the JustTweak stack as following:

```swift
static let tweakManager: TweakManager = {
    var tweakProviders: [TweakProvider] = []

    // Mutable TweakProvider (to override tweaks from other TweakProviders)
    let userDefaultsTweakProvider = UserDefaultsTweakProvider(userDefaults: UserDefaults.standard)
    tweakProviders.append(userDefaultsTweakProvider)
    
    // Optimizely (remote TweakProvider)
    let optimizelyTweakProvider = OptimizelyTweakProvider()
    optimizelyTweakProvider.userId = UUID().uuidString
    tweakProviders.append(optimizelyTweakProvider)

    // Firebase Remote Config (remote TweakProvider)
    let firebaseTweakProvider = FirebaseTweakProvider()
    tweakProviders.append(firebaseTweakProvider)

    // Local JSON-based TweakProvider (default TweakProvider)
    let jsonFileURL = Bundle.main.url(forResource: "LocalTweaks_example", withExtension: "json")!
    let localTweakProvider = LocalTweakProvider(jsonURL: jsonFileURL)
    tweakProviders.append(localTweakProvider)
    
    return TweakManager(tweakProviders: tweakProviders)
}()
```

- Implement the properties and constants for your features, backed by the `LocalTweakProvider`. Refer to `TweakAccessor.swift` for a starting point.

#### Using the code generator tool

- Define the stack configuration in a `config.json` file in the following format:

```json
{
    "tweakProviders": [
        {
            "type": "EphemeralTweakProvider",
            "macros": ["DEBUG", "CONFIGURATION_UI_TESTS"]
        },
        {
            "type": "UserDefaultsTweakProvider",
            "parameter": "UserDefaults.standard",
            "macros": ["DEBUG", "CONFIGURATION_DEBUG"]
        },
        {
            "type": "LocalTweakProvider",
            "parameter": "LocalTweaks_TopPriority_example",
            "macros": ["DEBUG"]
        },
        {
            "type": "LocalTweakProvider",
            "parameter": "LocalTweaks_example"
        }
    ],
    "shouldCacheTweaks": true,
    "usePropertyWrappers": true,
    "accessorName": "GeneratedTweakAccessor"
}
```

Supported tweak provider types are:

- `EphemeralTweakProvider`
- `UserDefaultsTweakProvider`
- `LocalTweakProvider`
- `CustomTweakProvider`

The content of the `parameter` value depends on the type:
- `EphemeralTweakProvider`: is not needed
- `UserDefaultsTweakProvider`: should specify the `UserDefaults` instance to be used 
- `LocalTweakProvider`: should specify the filename of the json file containing the tweaks
- `CustomTweakProvider`: should specify the filename of a file containing the setup code needed to instantiate and add your custom tweak provider.

```
...json
{
    "type": "CustomTweakProvider",
    "parameter": "FirebaseTweakProviderSetupCode",
    "macros": ["CONFIGURATION_APPSTORE"]
},
...
```

Example content from `FirebaseTweakProviderSetupCode`. Store any CustomTweakProvider setup code file in the same folder of `config.json` and mind not to add them in any target in Xcode.

```swift
let firebaseTweakProvider = FirebaseTweakProvider()
firebaseTweakProvider.someValue = true
tweakProviders.append(firebaseTweakProvider)
```

It's important to include the `tweakProviders.append(<#property_name#>)` statement at the end of your code block that will be included in the generated code.

Other supported configuration:

`shouldCacheTweaks`: enables/disable the JustTweak cache (see [Caching notes](#caching-notes)).
`usePropertyWrappers`: property wrappers are definitely one of the most exciting new features in Swift 5.1. In order to be used for the stack, they need a single instance of `TweakManager`. If this is not a possible approach for you codebase, you can set this value to `false` to allow the generation of code that doesn't rely on a `static let`. 
`accessorName`: the name of the generated class. 

- Add the following to your `Podfile`

```sh
script_phase :name => 'TweakAccessorGenerator',
             :script => '$PODS_ROOT/JustTweak/JustTweak/Assets/TweakAccessorGenerator.bundle/TweakAccessorGenerator \
             -l $SRCROOT/<path_to_the_local_tweaks_json_file> \
             -o $SRCROOT/<path_to_the_output_folder_for_the_generated_code> \
             -c $SRCROOT/<path_to_the_folder_containing_config.json>',
             :execution_position => :before_compile
```

Every time the target is built, the code generator tool will regenerate the code for the stack. It will include all the properties backing the features defined in the `LocalTweakProvider`.

- Add the generated files to you project and start using the stack.

## Usage

### Basic

If you have used the code generator tool, the generated stack includes all the feature flags. Simply allocate the accessor object (which name you have defined in the `.json` configuration and use it to access the feature flags.

```swift
let accessor = GeneratedTweakAccessor()
if accessor.meaningOfLife == 42 {
    ...
}
```

See `GeneratedTweakAccessor.swift` and `GeneratedTweakAccessor+Constants.swift` for an example of generated code.

### Advanced

If you decided to implement the stack code yourself, you'll have to implemented code for accessing the features via the `TweakManager`.

The three main features of JustTweak can be accessed from the `TweakManager` instance to drive code path decisions.

1. Checking if a feature is enabled

```swift
// check for a feature to be enabled
let enabled = tweakManager.isFeatureEnabled("some_feature")
if enabled {
    // enable the feature
} else {
    // default behaviour
}
```

2. Get the value of a flag for a given feature. `TweakManager` will return the value from the tweak provider with the highest priority and automatically fallback to the others if no set value is found.

Use either `tweakWith(feature:variable:)` or the provided property wrappers.

```swift
// check for a tweak value
let tweak = tweakManager.tweakWith(feature: "some_feature", variable: "some_flag")
if let tweak = tweak {
    // tweak was found in some tweak provider, use tweak.value
} else {
    // tweak was not found in any tweak provider
}
```

`@TweakProperty`, `@OptionalTweakProperty` and `@FallbackTweakProperty` property wrappers are available to mark properties representing feature flags. Mind that in order to use these property wrappers, a static instance of `TweakManager` is needed. 

```swift
@TweakProperty(feature: <#feature_key#>,
               variable: <#variable_key#>,
               tweakManager: <#TweakManager#>)
var labelText: String
```

```swift
@OptionalTweakProperty(fallbackValue: <#nillable_fallback_value#>,
                       feature: <#feature_key#>,
                       variable: <#variable_key#>,
                       tweakManager: <#TweakManager#>)
var meaningOfLife: Int?
```

```swift
@FallbackTweakProperty(fallbackValue: <#nillable_fallback_value#>,
                       feature: <#feature_key#>,
                       variable: <#variable_key#>,
                       tweakManager: <#TweakManager#>)
var shouldShowFeatureX: Bool
```

3. Run an A/B test

```swift
// check for a tweak value
let variation = tweakManager.activeVariation(for: "some_experiment")
if let variation = variation {
    // act according to the kind of variation (e.g. "control", "variation_1")
} else {
    // default behaviour
}
```

See `TweakAccessor.swift` for more info.


### Tweak Providers priority

The order of the objects in the `tweakProviders` array defines the priority of the tweak providers.

The `MutableTweakProvider` with the highest priority, such as `UserDefaultsTweakProvider` in the example above, will be used to reflect the changes made in the UI (`TweakViewController`). The `LocalTweakProvider` should have the lowest priority as it provides the default values from a local tweak provider and it's the one used by the `TweakViewController` to populate the UI.

### Migration notes

In order to migrate from manual to the code generated implementation, it is necessary to update to the new `.json` format. To aid with this process we have added the `GeneratedPropertyName` property to the tweak object. Set this value to align with your current property names in code, so that the generated accessor properties match your existing implementation.

### Caching notes

The `TweakManager` provides the option to cache the tweak values in order to improve performance. Caching is disabled by default but can be enabled via the `useCache` property. When enabled, there are two ways to reset the cache:

- call the `resetCache` method on the  `TweakManager`
- post a `TweakProviderDidChangeNotification` notification


### Update a mutable tweak provider at runtime

JustTweak comes with a ViewController that allows the user to edit the `MutableTweakProvider` with the highest priority.

```swift
func presentTweakViewController() {
    let tweakViewController = TweakViewController(style: .grouped, tweakManager: <#TweakManager#>)

    // either present it modally
    let tweaksNavigationController = UINavigationController(rootViewController:tweakViewController)
    tweaksNavigationController.navigationBar.prefersLargeTitles = true
    present(tweaksNavigationController, animated: true, completion: nil)

    // or push it on an existing UINavigationController
    navigationController?.pushViewController(tweakViewController, animated: true)
}
```

When a value is modified in any `MutableTweakProvider`, a notification is fired to give the clients the opportunity to react and reflect changes in the UI.

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    NotificationCenter.defaultCenter().addObserver(self,
                                                   selector: #selector(updateUI),
                                                   name: TweakProviderDidChangeNotification,
                                                   object: nil)
}

@objc func updateUI() {
    // update the UI accordingly
}
```


### Customization

JustTweak comes with three tweak providers out-of-the-box:

- `UserDefaultsTweakProvider` which is mutable and uses `UserDefaults` as a key/value store 
- `LocalTweakProvider` which is read-only and uses a JSON file that is meant to hold the default feature flagging setup
- `EphemeralTweakProvider` which is simply an instance of `NSMutableDictionary`

In addition, JustTweak defines `TweakProvider` and `MutableTweakProvider` protocols you can implement to create your own tweak provider to fit your needs. In the example project you can find some examples which you can use as a starting point.


## License

JustTweak is available under the Apache 2.0 license. See the LICENSE file for more info.


- Just Eat iOS team
