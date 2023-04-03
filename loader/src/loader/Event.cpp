#include <Geode/loader/Event.hpp>
#include <Geode/utils/ranges.hpp>

using namespace geode::prelude;

void EventListenerProtocol::enable() {
    Event::listeners().push_back(this);
}

void EventListenerProtocol::disable() {
    Event::removedListeners().insert(this);
    ranges::remove(Event::listeners(), this);
}

EventListenerProtocol::~EventListenerProtocol() {
    this->disable();
}

Event::~Event() {}

void Event::postFrom(Mod* m) {
    if (m) this->sender = m;

    std::vector<EventListenerProtocol*> listeners_copy = Event::listeners();
    for (auto h : listeners_copy) {
        // if an event listener gets destroyed in the middle of this loop, we 
        // need to handle that
        if (Event::removedListeners().count(h)) continue;
        if (h->passThrough(this) == ListenerResult::Stop) {
            break;
        }
    }
    Event::removedListeners().clear();
}

std::unordered_set<EventListenerProtocol*>& Event::removedListeners() {
    static std::unordered_set<EventListenerProtocol*> listeners;
    return listeners;
}

std::vector<EventListenerProtocol*>& Event::listeners() {
    static std::vector<EventListenerProtocol*> listeners;
    return listeners;
}

void Event::prioritize(EventListenerProtocol* listener) {
    ranges::move(Event::listeners(), listener, 0);
}
