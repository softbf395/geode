#include <Geode/DefaultInclude.hpp>

#if defined(GEODE_IS_MACOS)

#import <Cocoa/Cocoa.h>
#include "../load.hpp"
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <unistd.h>
#include <tulip/TulipHook.hpp>
#include <array>
#include <ghc/filesystem.hpp>
#include <Geode/Loader.hpp>
#include "../../loader/LoaderImpl.hpp"
#include <thread>
#include <variant>
#include <objc/runtime.h>

using namespace geode::prelude;

std::length_error::~length_error() _NOEXCEPT {} // do not ask...

// camila has an old ass macos and this function turned
// from dynamic to static thats why she needs to define it
// this is what old versions does to a silly girl

void updateFiles() {
    auto frameworkDir = dirs::getGameDir() / "Frameworks";
    auto updatesDir = dirs::getGeodeDir() / "update";
    auto resourcesDir = dirs::getGeodeResourcesDir();

    if (ghc::filesystem::exists(frameworkDir) && ghc::filesystem::exists(updatesDir)) {
        std::error_code error;
        auto bootFile = "GeodeBootstrapper.dylib";
        auto geodeFile = "Geode.dylib";

        if (ghc::filesystem::exists(updatesDir / bootFile)) {
            ghc::filesystem::remove(frameworkDir / bootFile, error);
            if (error) {
                log::warn("Couldn't remove old GeodeBootstrapper.dylib: {}", error.message());
            }
            else {
                ghc::filesystem::rename(updatesDir / bootFile, frameworkDir / bootFile, error);
                if (error) {
                    log::warn("Couldn't move new GeodeBootstrapper.dylib: {}", error.message());
                }
                else {
                    log::info("Updated GeodeBootstrapper.dylib");
                }
            }
        }
        if (ghc::filesystem::exists(updatesDir / geodeFile)) {
            ghc::filesystem::remove(frameworkDir / geodeFile, error);
            if (error) {
                log::warn("Couldn't remove old Geode.dylib: {}", error.message());
            }
            else {
                ghc::filesystem::rename(updatesDir / geodeFile, frameworkDir / geodeFile, error);
                if (error) {
                    log::warn("Couldn't move new Geode.dylib: {}", error.message());
                }
                else {
                    log::info("Updated Geode.dylib");
                }
            }
        }
        if (ghc::filesystem::exists(updatesDir / "resources")) {
            ghc::filesystem::remove_all(resourcesDir / "geode.loader", error);
            if (error) {
                log::warn("Couldn't remove old resources: {}", error.message());
            }
            else {
                ghc::filesystem::rename(updatesDir / "resources", resourcesDir / "geode.loader", error);
                if (error) {
                    log::warn("Couldn't move new resources: {}", error.message());
                }
                else {
                    log::info("Updated resources");
                }
            }
        }
        ghc::filesystem::remove_all(updatesDir, error);
        if (error) {
            log::warn("Couldn't remove old update directory: {}", error.message());
        }
    }
}

$execute {
    new EventListener(+[](LoaderUpdateEvent* event) {
        if (std::holds_alternative<UpdateFinished>(event->status)) {
            updateFiles();
        }
        return;
    }, LoaderUpdateFilter());
};

void updateGeode() {
    ghc::filesystem::path oldSavePath = "/Users/Shared/Geode/geode";
    auto newSavePath = dirs::getSaveDir() / "geode";
    if (ghc::filesystem::exists(oldSavePath)) {
        std::error_code error;

        ghc::filesystem::rename(oldSavePath, newSavePath, error);
        if (error) {
            log::warn("Couldn't migrate old save files from {} to {}", oldSavePath.string(), newSavePath.string());
        }
    }

    updateFiles();
}

extern "C" void fake() {}

static IMP s_applicationDidFinishLaunching;
void applicationDidFinishLaunching(id self, SEL sel, NSNotification* notification) {
    updateGeode();

    int exitCode = geodeEntry(nullptr);
    if (exitCode != 0)
        return;
    
    using Type = decltype(&applicationDidFinishLaunching);
    return reinterpret_cast<Type>(s_applicationDidFinishLaunching)(self, sel, notification);
}


bool loadGeode() {
    Class class_ = objc_getClass("AppController");
    SEL selector = @selector(applicationDidFinishLaunching:);
    IMP function = (IMP)applicationDidFinishLaunching;
    using Type = decltype(&applicationDidFinishLaunching);

    s_applicationDidFinishLaunching = class_replaceMethod(class_, selector, function, @encode(Type));
    
    return true;
}

__attribute__((constructor)) void _entry() {
    if (!loadGeode())
        return;
}

#endif