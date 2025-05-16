//
//  Page+Eaten.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 14/05/25.
//

extension Page {
    // MARK: - "I've eaten…" flow pages

    /// Step 1: Choose snack or meal
    static var foodType: Page {
        var page = Page(
            id: "foodType",
            image: nil,
            title: "I've eaten…",
            body: "Did you have a snack or normal meal?",
            buttonFirstLabel: "Snack",
            buttonSecondLabel: "Meal"
        )
        // Navigate to timeRelative on both choices
        page.buttonFirstPage = PageRef(id: Page.timeRelative.id, type: Page.timeRelative.type)
        page.buttonSecondPage = PageRef(id: Page.timeRelative.id, type: Page.timeRelative.type)
        return page
    }

    /// Step 2: Relative time for snack/meal
    static var timeRelative: Page {
        var page = Page(
            id: "timeRelative",
            image: nil,
            title: "You had your snack…",
            body: "",
            buttonFirstLabel: "In the last hour",
            buttonSecondLabel: "Earlier than the last hour"
        )
        // "In the last hour" skips to quantity
        page.buttonFirstPage = PageRef(id: Page.quantity.id, type: Page.quantity.type)
        // "Earlier than" goes to dateTime
        page.buttonSecondPage = PageRef(id: Page.dateTime.id, type: Page.dateTime.type)
        return page
    }

    /// Step 3: Specify exact date/time
    static var dateTime: Page {
        var page = Page(
            id: "dateTime",
            image: nil,
            title: "Specify the date and time of your snack.",
            body: "",
            buttonFirstLabel: "Next",
            buttonSecondLabel: nil
        )
        page.buttonFirstPage = PageRef(id: Page.quantity.id, type: Page.quantity.type)
        return page
    }

    /// Step 4: Quantity relative to usual
    static var quantity: Page {
        var page = Page(
            id: "quantity",
            image: nil,
            title: "Was your snack…",
            body: "",
            buttonFirstLabel: "more than usual",
            buttonSecondLabel: "the same amount as usual"
        )
        // Both first and second lead to nutrient
        page.buttonFirstPage = PageRef(id: Page.nutrient.id, type: Page.nutrient.type)
        page.buttonSecondPage = PageRef(id: Page.nutrient.id, type: Page.nutrient.type)
        return page
    }

    /// Step 5: Nutrient content question
    static var nutrient: Page {
        var page = Page(
            id: "nutrient",
            image: nil,
            title: "Did your snack contain either a significant proportion of protein, fiber and/or fat in it?",
            body: "",
            buttonFirstLabel: "Yes",
            buttonSecondLabel: "No"
        )
        // Both choices lead to confirm
        page.buttonFirstPage = PageRef(id: Page.confirm.id, type: Page.confirm.type)
        page.buttonSecondPage = PageRef(id: Page.confirm.id, type: Page.confirm.type)
        return page
    }

    /// Step 6: Confirmation
    static var confirm: Page {
        let page = Page(
            id: "confirm",
            image: nil,
            title: "Confirm",
            body: "",
            buttonFirstLabel: "Confirm",
            buttonSecondLabel: nil
        )
        return page
    }
}
