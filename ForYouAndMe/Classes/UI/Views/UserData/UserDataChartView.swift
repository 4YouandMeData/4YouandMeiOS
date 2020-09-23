//
//  UserDataChartView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 04/09/2020.
//

import UIKit
import PureLayout
import Charts

enum StudyPeriod: Int, CaseIterable {
    case day
    case week
    case month
    case year
    
    var title: String {
        switch self {
        case .day:
            return "DAY"
        case .week:
            return "WEEK"
        case .month:
            return "MONTH"
        case .year:
            return "YEAR"
        }
    }
    
    var periodString: String {
        switch self {
        case .day:
            return periodString(formatter: "EEEE, MMM d, yyyy")
        case .week:
            return periodString()
        case .month:
            return periodString(formatter: "MMMM yyyy")
        case .year:
            return periodString(formatter: "MMMM yyyy")
        }
    }
    
    func periodString(formatter: String = "MMM dd, yyyy") -> String {
        let dates = getStartAndEndData()
        let startDate = dates.startDate.string(withFormat: formatter)
        let endDate = dates.endDate.string(withFormat: formatter)
        switch self {
        case .day:
            return "\(startDate)"
        case .week, .month, .year:
            return "\(startDate)" + " - " + "\(endDate)"

        }
    }
    
    func getStartAndEndData() -> (startDate: Date, endDate: Date) {
        var startDate = Date()
        
        switch self {
        case .day:
            startDate = startDate.getDate(for: -1)
        case .month:
            startDate = startDate.getDate(for: -30)
        case .week:
            startDate = startDate.getDate(for: -7)
        case .year:
            startDate = startDate.getDate(for: -364)
        }
        return (startDate: startDate, endDate: Date().getDate(for: -1))
    }
    
    func getInterval() -> Int {
        switch self {
        case .day:
            return 1
        case .month:
            return 4
        case .week:
            return 1
        case .year:
            return 121
        }
    }
    
    func getXAxisRangeValues() -> [String] {
        let dates = self.getStartAndEndData()
        let startDate = dates.startDate
        
        switch self {
        case .day:
            return startDate.getDates(for: self.getInterval(), interval: 1, format: dayTime)
        case .week:
            return startDate.getDates(for: self.getInterval(), interval: 6, format: dayShort)
        case .month:
            return startDate.getDates(for: self.getInterval(), interval: 3, format: shortDate)
        case .year:
            return startDate.getDates(for: self.getInterval(), interval: 3, format: shortDate)
        }
    }
}

class UserDataChartView: UIView {
    
    private static let chartBackgroundHeight: CGFloat = 280.0
    private var plotColor: UIColor
    private var values: [String]
    private var studyPeriod: StudyPeriod
    
    private let chartView: LineChartView = {
        let chartView = LineChartView()
        return chartView
    }()
    
    init(title: String,
         plotColor: UIColor,
         values: [String],
         studyPeriod: StudyPeriod) {
        
        self.plotColor = plotColor
        self.values = values
        self.studyPeriod = studyPeriod
        
        super.init(frame: .zero)
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 30.0)
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        stackView.addLabel(withText: title, fontStyle: .paragraph, colorType: .primaryText, textAlignment: .left)
        
        let chartBackground = UIView()
        chartBackground.backgroundColor = ColorPalette.color(withType: .secondary)
        chartBackground.round(radius: 4.0)
        chartBackground.autoSetDimension(.height, toSize: Self.chartBackgroundHeight)
        chartBackground.addShadowCell()
        
        chartBackground.addSubview(self.chartView)
        self.chartView.autoPinEdgesToSuperviewEdges()
        
        stackView.addArrangedSubview(chartBackground)
        
        self.setupUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        
        //General Settings
        self.chartView.chartDescription?.enabled = false
        self.chartView.dragEnabled = false
        self.chartView.setScaleEnabled(false)
        self.chartView.pinchZoomEnabled = false
        self.chartView.rightAxis.enabled = true
        self.chartView.leftAxis.enabled = false
        self.chartView.leftAxis.drawGridLinesEnabled = false
        self.chartView.drawGridBackgroundEnabled = false
        self.chartView.extraBottomOffset = 20
        self.chartView.extraLeftOffset = 25
        self.chartView.extraTopOffset = 20
        self.chartView.clipsToBounds = false
    
        //Legend
        self.chartView.legend.form = .line
        self.chartView.legend.textColor = self.plotColor
        self.chartView.legend.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        self.chartView.legend.xOffset = -10

//        self.chartView.legend.yOffset = 20
        
        //Axis
        self.configureXAxis()
        self.configureYAxis()
        
        //Y-Axis Formatter
        
        //X-Axis Formatter
        let xAxisFormatter = XAxisValueFormatter(chart: self.chartView)
        xAxisFormatter.studyPeriod = self.studyPeriod
        
        self.chartView.xAxis.valueFormatter = xAxisFormatter
        
        // Y-Axis limit line
        let ll1 = ChartLimitLine(limit: 70, label: "")
        ll1.lineWidth = 2
        ll1.lineDashLengths = [10, 10]
        ll1.lineColor = ColorPalette.color(withType: .inactive)
        
        let rightAxis = chartView.rightAxis
        rightAxis.removeAllLimitLines()
        rightAxis.addLimitLine(ll1)
        rightAxis.axisMaximum = 200
        rightAxis.axisMinimum = 0
        rightAxis.drawLimitLinesBehindDataEnabled = true
        
        //Values
        let testCount: Int = 10
        let testRange: UInt32 = 100
        
        let values = (0..<testCount).map { (index) -> ChartDataEntry in
            let val = Double(arc4random_uniform(testRange) + 3)
            return ChartDataEntry(x: Double(index), y: val, icon: ImagePalette.image(withName: .circular))
        }
        
        let set1 = LineChartDataSet(entries: values, label: studyPeriod.periodString)
        set1.drawIconsEnabled = false
        set1.drawValuesEnabled = false
        set1.drawCirclesEnabled = true
        set1.drawCircleHoleEnabled = true
        set1.highlightLineDashLengths = [5, 2.5]
        
        set1.setColor(self.plotColor)
        set1.setCircleColor(self.plotColor)
        set1.lineWidth = 2
        set1.circleRadius = 6
        set1.circleHoleColor = .white
        set1.valueFont = .systemFont(ofSize: 9)
        //        set1.formLineDashLengths = [5, 2.5]
        //        set1.formLineWidth = 1
        //        set1.formSize = 15
        
        let data = LineChartData(dataSet: set1)
        self.chartView.data = data
    }
    
    fileprivate func configureXAxis() {
        self.chartView.xAxis.labelPosition = XAxis.LabelPosition.bottom
        self.chartView.xAxis.drawGridLinesEnabled = false
        self.chartView.xAxis.forceLabelsEnabled = true
        self.chartView.xAxis.axisLineColor = UIColor(hexString: "#505050")!
        self.chartView.xAxis.labelTextColor = UIColor(hexString: "#505050")!
        self.chartView.xAxis.labelFont = FontPalette.fontStyleData(forStyle: .header3).font
        self.chartView.xAxis.wordWrapEnabled = true
        self.chartView.xAxis.yOffset = 10
//        self.chartView.xAxis.centerAxisLabelsEnabled = true
        
        let range = self.getXAxisRange(periodType: self.studyPeriod)
        self.chartView.xAxis.labelCount = range.interval
        self.chartView.xAxis.axisMinimum = range.min
        self.chartView.xAxis.axisMaximum = range.max
    }
    
    fileprivate func configureYAxis() {
        let rightAxis = chartView.rightAxis
        rightAxis.removeAllLimitLines()
        rightAxis.centerAxisLabelsEnabled = true
        rightAxis.forceLabelsEnabled = true
        rightAxis.axisLineColor = UIColor(hexString: "#505050")!
        rightAxis.labelTextColor = UIColor(hexString: "#505050")!
        rightAxis.labelFont = FontPalette.fontStyleData(forStyle: .header3).font
        rightAxis.drawGridLinesEnabled = false
        rightAxis.drawLimitLinesBehindDataEnabled = true
        rightAxis.drawZeroLineEnabled = true
    }
    
    fileprivate func getXAxisRange(periodType: StudyPeriod) -> (min: Double, max: Double, interval: Int) {
        var value: (min: Double, max: Double, interval: Int)!
        if periodType == .week {
            value = (min: 0, max: 6, interval: 6)
        } else if periodType == .day {
            value = (min: 0, max: 4, interval: 4)
        } else {
            value = (min: 0, max: 3, interval: 3)
        }
        return value
    }
}

/// Customised x-axis formmater to render the x-axis strings with format based on the study type and period type.
class XAxisValueFormatter: NSObject, IAxisValueFormatter {
    weak var chart: LineChartView?
    var studyPeriod: StudyPeriod?
    
    init(chart: LineChartView) {
        self.chart = chart
    }
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        guard let studyPeriod = studyPeriod else { return "\(Int(value))" }
        
        let index = Int(value)
        
        switch studyPeriod {
        case .day, .week, .year, .month:
            if index < studyPeriod.getXAxisRangeValues().count {
                return studyPeriod.getXAxisRangeValues()[index]
            } else {
                return "\(value)"
            }
        }
    }
}
