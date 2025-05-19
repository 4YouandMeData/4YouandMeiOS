//
//  Page+Doses.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 19/05/25.
//

extension Page {
    // MARK: - "I've eaten…" flow pages

    /// Step 1: Choose snack or meal
    static var doseType: Page {
        var page = Page(
            id: "doseType",
            image: nil,
            title: "Add a dose",
            body: "What type did you use? ",
            buttonFirstLabel: "Pump",
            buttonSecondLabel: "Insulin"
        )
        // Navigate to timeRelative on both choices
        page.buttonFirstPage = PageRef(id: Page.timeRelative.id, type: Page.timeRelative.type)
        page.buttonSecondPage = PageRef(id: Page.timeRelative.id, type: Page.timeRelative.type)
        return page
    }

    /// Step 2: Relative time for snack/meal
    static var doseDateTime: Page {
        var page = Page(
            id: "timeRelative",
            image: nil,
            title: "",
            body: "",
            buttonFirstLabel: "",
            buttonSecondLabel: ""
        )
        // "In the last hour" skips to quantity
        page.buttonFirstPage = PageRef(id: Page.quantity.id, type: Page.quantity.type)
        // "Earlier than" goes to dateTime
        page.buttonSecondPage = PageRef(id: Page.dateTime.id, type: Page.dateTime.type)
        return page
    }

    /// Step 3: Specify exact date/time
    static var doseAmount: Page {
        var page = Page(
            id: "dateTime",
            image: nil,
            title: "",
            body: "",
            buttonFirstLabel: "",
            buttonSecondLabel: nil
        )
        page.buttonFirstPage = PageRef(id: Page.quantity.id, type: Page.quantity.type)
        return page
    }
}
