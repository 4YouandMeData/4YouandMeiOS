//
//  Page+Menstrual.swift
//  ForYouAndMe
//
//  FUAM-2935 — Page references for the menstrual cycle wizard. Mirrors the
//  Page+Eaten layout used by FoodEntryCoordinator.
//

extension Page {
    static var menstrualWhen: Page {
        var page = Page(
            id: "menstrualWhen",
            image: nil,
            title: "Menstrual Cycle",
            body: "When did the bleeding occur?",
            buttonFirstLabel: "Today",
            buttonSecondLabel: "Earlier than today"
        )
        page.buttonFirstPage = PageRef(id: Page.menstrualFlow.id, type: Page.menstrualFlow.type)
        page.buttonSecondPage = PageRef(id: Page.menstrualDate.id, type: Page.menstrualDate.type)
        return page
    }

    static var menstrualDate: Page {
        var page = Page(
            id: "menstrualDate",
            image: nil,
            title: "When?",
            body: "",
            buttonFirstLabel: "Next",
            buttonSecondLabel: nil
        )
        page.buttonFirstPage = PageRef(id: Page.menstrualFlow.id, type: Page.menstrualFlow.type)
        return page
    }

    static var menstrualFlow: Page {
        var page = Page(
            id: "menstrualFlow",
            image: nil,
            title: "How heavy was your flow?",
            body: "",
            buttonFirstLabel: "Next",
            buttonSecondLabel: nil
        )
        page.buttonFirstPage = PageRef(id: Page.menstrualPeriodRelated.id, type: Page.menstrualPeriodRelated.type)
        return page
    }

    static var menstrualPeriodRelated: Page {
        var page = Page(
            id: "menstrualPeriodRelated",
            image: nil,
            title: "Was this related to a menstrual period?",
            body: "",
            buttonFirstLabel: "Next",
            buttonSecondLabel: nil
        )
        page.buttonFirstPage = PageRef(id: Page.menstrualNote.id, type: Page.menstrualNote.type)
        return page
    }

    static var menstrualNote: Page {
        let page = Page(
            id: "menstrualNote",
            image: nil,
            title: "Anything to add?",
            body: "",
            buttonFirstLabel: "Done",
            buttonSecondLabel: nil
        )
        return page
    }
}
