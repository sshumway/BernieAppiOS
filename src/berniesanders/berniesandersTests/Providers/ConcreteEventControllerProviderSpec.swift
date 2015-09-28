import Foundation
import Quick
import Nimble
import berniesanders

public class ConcreteEventControllerProviderSpec : QuickSpec {
    var subject : ConcreteEventControllerProvider!
    let dateFormatter = NSDateFormatter()
    let theme = FakeTheme()
    let eventPresenter = EventPresenter()
    
    override public func spec() {
        describe("providing an instance with an event") {
            beforeEach {
                self.subject = ConcreteEventControllerProvider(
                    eventPresenter: self.eventPresenter,
                    dateFormatter: self.dateFormatter,
                    theme: self.theme
                )
            }
            
            it("should return a correctly configured instance") {
                let event = TestUtils.eventWithName("some event")
                
                let controller = self.subject.provideInstanceWithEvent(event)
                
                expect(controller).to(beAnInstanceOf(EventController.self))
                expect(controller.event).to(beIdenticalTo(event))
                expect(controller.eventPresenter).to(beIdenticalTo(self.eventPresenter))
                expect(controller.dateFormatter).to(beIdenticalTo(self.dateFormatter))
                expect(controller.theme as? FakeTheme).to(beIdenticalTo(self.theme))
            }
        }
    }
}