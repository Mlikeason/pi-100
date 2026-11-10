#!/usr/bin/env python3
"""Generate a deterministic Xcode project using folder-synchronized sources (Xcode 16+)."""
from pathlib import Path
import json, plistlib, shutil, hashlib
root = Path(__file__).resolve().parents[1]
ios = root / 'ios'
objects = {}
def add(key, value):
    ident = hashlib.sha256(key.encode()).hexdigest()[:24].upper()
    objects[ident] = value
    return ident

def config(name, settings): return add(name, {'isa':'XCBuildConfiguration', 'name':'Debug' if 'Debug' in name else 'Release', 'buildSettings':settings})
def config_list(name, debug, release):
    return add(name, {'isa':'XCConfigurationList','buildConfigurations':[debug,release], 'defaultConfigurationIsVisible':0,'defaultConfigurationName':'Release'})
common = {'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','ENABLE_USER_SCRIPT_SANDBOXING':'YES','SWIFT_STRICT_CONCURRENCY':'complete'}
project_configs = config_list('ProjectConfigs',config('ProjDebug',{**common,'DEBUG_INFORMATION_FORMAT':'dwarf','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG','SWIFT_OPTIMIZATION_LEVEL':'-Onone','ENABLE_TESTABILITY':'YES','ONLY_ACTIVE_ARCH':'YES'}),config('ProjRelease',{**common,'DEBUG_INFORMATION_FORMAT':'dwarf-with-dsym','SWIFT_COMPILATION_MODE':'wholemodule','SWIFT_OPTIMIZATION_LEVEL':'-O','VALIDATE_PRODUCT':'YES'}))
products = []; targets = []; groups = []
for name, kind in [('Pi100','application'),('Pi100Tests','bundle.unit-test'),('Pi100UITests','bundle.ui-testing')]:
    isapp = kind == 'application'
    group = add(name+'Group',{'isa':'PBXFileSystemSynchronizedRootGroup','path':name,'sourceTree':'<group>'})
    groups.append(group)
    product = add(name+'Product',{'isa':'PBXFileReference','explicitFileType':'wrapper.application' if isapp else 'wrapper.cfbundle','path':name+('.app' if isapp else '.xctest'),'sourceTree':'BUILT_PRODUCTS_DIR','includeInIndex':0})
    products.append(product)
    settings = {'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'me.zhuhong.pi100'+('' if isapp else '.'+name), 'CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':'KW9NTQUH4T','TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','GENERATE_INFOPLIST_FILE':'YES'}
    if isapp:
        settings.update({'INFOPLIST_FILE':'Pi100/Resources/Info.plist','CODE_SIGN_ENTITLEMENTS':'Pi100/Resources/Pi100.entitlements','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','MARKETING_VERSION':'1.0','CURRENT_PROJECT_VERSION':'3','INFOPLIST_KEY_CFBundleDisplayName':'π 100','INFOPLIST_KEY_LSApplicationCategoryType':'public.app-category.education','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','SWIFT_EMIT_LOC_STRINGS':'YES'})
        exception = add('ResourcesException', {'isa':'PBXFileSystemSynchronizedBuildFileExceptionSet','membershipExceptions':['Resources/Info.plist','Resources/Pi100.entitlements'],'target':hashlib.sha256(name.encode()).hexdigest()[:24].upper()})
        objects[group]['exceptions']=[exception]
    elif kind == 'bundle.unit-test':
        settings.update({'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Pi100.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Pi100','BUNDLE_LOADER':'$(TEST_HOST)'})
    else: settings['TEST_TARGET_NAME']='Pi100'
    configs=config_list(name+'Configs',config(name+'Debug',settings),config(name+'Release',settings))
    phases=[add(name+phase,{'isa':'PBX'+phase+'BuildPhase','buildActionMask':2147483647,'files':[],'runOnlyForDeploymentPostprocessing':0}) for phase in ['Sources','Frameworks','Resources']]
    targets.append(add(name,{'isa':'PBXNativeTarget','buildConfigurationList':configs,'buildPhases':phases,'buildRules':[],'dependencies':[],'fileSystemSynchronizedGroups':[group],'name':name,'productName':name,'productReference':product,'productType':'com.apple.product-type.'+kind}))
for index in [1,2]:
    dependency=add('Depend'+str(index),{'isa':'PBXTargetDependency','target':targets[0]})
    objects[targets[index]]['dependencies']=[dependency]
product_group=add('Products',{'isa':'PBXGroup','children':products,'name':'Products','sourceTree':'<group>'})
main=add('Main',{'isa':'PBXGroup','children':groups+[product_group],'sourceTree':'<group>'})
project=add('Project',{'isa':'PBXProject','attributes':{'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2720'},'buildConfigurationList':project_configs,'developmentRegion':'en','knownRegions':['en','zh-Hans','Base'],'mainGroup':main,'productRefGroup':product_group,'preferredProjectObjectVersion':77,'projectDirPath':'','projectRoot':'','targets':targets})
# OpenStep plist syntax, JSON strings are compatible quoted strings.
def encode(x, level=0):
    if isinstance(x,dict): return '{\n'+''.join('  '*(level+1)+json.dumps(str(k))+ ' = '+encode(v,level+1)+';\n' for k,v in x.items())+'  '*level+'}'
    if isinstance(x,list): return '('+', '.join(encode(v,level) for v in x)+')'
    if isinstance(x,int): return str(x)
    return json.dumps(x,ensure_ascii=False)
(ios/'Pi100.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n'+encode({'archiveVersion':1,'classes':{},'objectVersion':77,'objects':objects,'rootObject':project})+'\n')
def ref(i): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[i]}" BuildableName="{["Pi100.app","Pi100Tests.xctest","Pi100UITests.xctest"][i]}" BlueprintName="{["Pi100","Pi100Tests","Pi100UITests"][i]}" ReferencedContainer="container:Pi100.xcodeproj"/>'
(ios/'Pi100.xcodeproj/xcshareddata/xcschemes/Pi100.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2720" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref(0)}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref(1)}</TestableReference><TestableReference skipped="NO">{ref(2)}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(0)}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(0)}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
resources=ios/'Pi100/Resources'
with (resources/'Info.plist').open('wb') as f:
    plistlib.dump({'CFBundleDevelopmentRegion':'$(DEVELOPMENT_LANGUAGE)','CFBundleLocalizations':['en','zh-Hans'],'ITSAppUsesNonExemptEncryption':False,'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'UISupportedInterfaceOrientations~ipad':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight']},f)
with (resources/'Pi100.entitlements').open('wb') as f: plistlib.dump({'com.apple.developer.game-center':True},f)
with (resources/'PrivacyInfo.xcprivacy').open('wb') as f:
    plistlib.dump({'NSPrivacyTracking':False,'NSPrivacyTrackingDomains':[],'NSPrivacyCollectedDataTypes':[],'NSPrivacyAccessedAPITypes':[{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryUserDefaults','NSPrivacyAccessedAPITypeReasons':['CA92.1']},{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategorySystemBootTime','NSPrivacyAccessedAPITypeReasons':['35F9.1']}]},f)
assets=resources/'Assets.xcassets'
(assets/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}},indent=2))
(assets/'AppIcon.appiconset/Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2))
shutil.copyfile(root/'icon-1024.png',assets/'AppIcon.appiconset/AppIcon.png')
print('Generated ios/Pi100.xcodeproj')
