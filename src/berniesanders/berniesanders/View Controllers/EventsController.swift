import UIKit
import PureLayout
import QuartzCore
import CoreActionSheetPicker

// swiftlint:disable type_body_length
class EventsController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    let eventRepository: EventRepository
    let eventPresenter: EventPresenter
    private let eventControllerProvider: EventControllerProvider
    private let analyticsService: AnalyticsService
    private let tabBarItemStylist: TabBarItemStylist
    let theme: Theme

    let zipCodeTextField = UITextField.newAutoLayoutView()
    let searchRadiusField = UITextField.newAutoLayoutView()
    let searchEventsButton = UIButton.newAutoLayoutView()
    let resultsTableView = UITableView.newAutoLayoutView()
    let noResultsLabel = UILabel.newAutoLayoutView()
    let instructionsLabel = UILabel.newAutoLayoutView()
    let loadingActivityIndicatorView = UIActivityIndicatorView.newAutoLayoutView()

    var events: Array<Event>!

    init(eventRepository: EventRepository,
        eventPresenter: EventPresenter,
        eventControllerProvider: EventControllerProvider,
        analyticsService: AnalyticsService,
        tabBarItemStylist: TabBarItemStylist,
        theme: Theme) {

        self.eventRepository = eventRepository
        self.eventPresenter = eventPresenter
        self.eventControllerProvider = eventControllerProvider
        self.analyticsService = analyticsService
        self.tabBarItemStylist = tabBarItemStylist
        self.theme = theme

        self.events = []

        super.init(nibName: nil, bundle: nil)

        self.tabBarItemStylist.applyThemeToBarBarItem(self.tabBarItem,
            image: UIImage(named: "eventsTabBarIconInactive")!,
            selectedImage: UIImage(named: "eventsTabBarIcon")!)
        self.title = NSLocalizedString("Events_tabBarTitle", comment: "")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Events_navigationTitle", comment: "")
        let backBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Events_backButtonTitle", comment: ""),
            style: UIBarButtonItemStyle.Plain,
            target: nil, action: nil)

        navigationItem.backBarButtonItem = backBarButtonItem

        edgesForExtendedLayout = .None
        resultsTableView.dataSource = self
        resultsTableView.delegate = self
        resultsTableView.registerClass(EventListTableViewCell.self, forCellReuseIdentifier: "eventCell")

        instructionsLabel.text = NSLocalizedString("Events_instructions", comment: "")

        setNeedsStatusBarAppearanceUpdate()

        self.setupSubviews()
        self.applyTheme()
        self.setupConstraints()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        if let selectedRowIndexPath = self.resultsTableView.indexPathForSelectedRow {
            self.resultsTableView.deselectRowAtIndexPath(selectedRowIndexPath, animated: false)
        }
    }

    // MARK: <UITableViewDataSource>

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        // swiftlint:disable force_cast
        let cell = tableView.dequeueReusableCellWithIdentifier("eventCell") as! EventListTableViewCell
        // swiftlint:enable force_cast

        let event = events[indexPath.row]

        cell.addressLabel.textColor = self.theme.eventsListColor()
        cell.addressLabel.font = self.theme.eventsListFont()
        cell.attendeesLabel.textColor = self.theme.eventsListColor()
        cell.attendeesLabel.font = self.theme.eventsListFont()
        cell.nameLabel.textColor = self.theme.eventsListColor()
        cell.nameLabel.font = self.theme.eventsListFont()

        return self.eventPresenter.presentEvent(event, cell: cell)
    }

    // MARK: <UITableViewDelegate>

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 90
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let event = self.events[indexPath.row]
        let controller = self.eventControllerProvider.provideInstanceWithEvent(event)
        self.analyticsService.trackContentViewWithName(event.name, type: .Event, id: event.url.absoluteString)
        self.navigationController?.pushViewController(controller, animated: true)
    }

    // MARK: <UITextFieldDelegate>

    func textFieldDidBeginEditing(textField: UITextField) {
        if textField.tag == self.zipCodeTextField.tag {
            self.analyticsService.trackCustomEventWithName("Tapped on ZIP Code text field on Events", customAttributes: nil)
        }
    }
    
    // MARK: Actions

    func didTapSearch(sender: UIButton!) {
        let enteredZipCode = self.zipCodeTextField.text!
        
        let searchRadiusText = String(self.searchRadiusField.text!.characters.split(" ")[0])
        let enteredSearchDistance: Float = Float(searchRadiusText) ?? 50.0
        
        self.analyticsService.trackSearchWithQuery(enteredZipCode, context: .Events)

        zipCodeTextField.resignFirstResponder()

        self.instructionsLabel.hidden = true
        self.resultsTableView.hidden = true
        self.noResultsLabel.hidden = true

        loadingActivityIndicatorView.startAnimating()

        self.eventRepository.fetchEventsWithZipCode(enteredZipCode, radiusMiles: enteredSearchDistance,
            completion: { (events: Array<Event>) -> Void in
                let matchingEventsFound = events.count > 0
                self.events = events

                self.noResultsLabel.hidden = matchingEventsFound
                self.resultsTableView.hidden = !matchingEventsFound
                self.loadingActivityIndicatorView.stopAnimating()

                self.resultsTableView.reloadData()
            }) { (error: NSError) -> Void in
                self.analyticsService.trackError(error, context: "Events")
                self.noResultsLabel.hidden = false
                self.loadingActivityIndicatorView.stopAnimating()
        }
    }
    
    func didTapSetZipCodeDone(sender: UIButton!) {
        self.zipCodeTextField.resignFirstResponder()
    }

    func didTapSetZipCodeCancel(sender: UIButton!) {
        self.analyticsService.trackCustomEventWithName("Cancelled ZIP Code search on Events", customAttributes: nil)
        self.zipCodeTextField.resignFirstResponder()
    }
    
    func didTapSearchRadius(sender: UITextField!) {
        if self.zipCodeTextField.isFirstResponder() {
            self.zipCodeTextField.resignFirstResponder()
        }
        let distanceUnit = NSLocalizedString("Events_searchRadiusUnit", comment: "")
        let distances = ["5 \(distanceUnit)", "10 \(distanceUnit)", "20 \(distanceUnit)", "50 \(distanceUnit)", "100 \(distanceUnit)", "250 \(distanceUnit)"]
        
        let distancePicker = ActionSheetStringPicker(
            title: "Distance",
            rows: distances,
            initialSelection: 3,
            doneBlock: { picker, index, value in
                self.searchRadiusField.text = "\(value)"
                self.searchRadiusField.resignFirstResponder()
            },
            cancelBlock: { ActionStringCancelBlock in
                self.searchRadiusField.resignFirstResponder()
            },
            origin: sender)
        
        distancePicker.titleTextAttributes = [NSForegroundColorAttributeName: self.theme.eventsDistancePickerTitleColor()]
        distancePicker.showActionSheetPicker()
        distancePicker.toolbar.barTintColor = self.theme.eventsDistancePickerBarColor()
    }

    // MARK: Private

    func setupSubviews() {
        view.addSubview(zipCodeTextField)
        view.addSubview(searchRadiusField)
        view.addSubview(searchEventsButton)
        view.addSubview(instructionsLabel)
        view.addSubview(resultsTableView)
        view.addSubview(noResultsLabel)
        view.addSubview(loadingActivityIndicatorView)
        
        var controlTag = 1

        zipCodeTextField.delegate = self
        zipCodeTextField.tag = controlTag++
        zipCodeTextField.placeholder = NSLocalizedString("Events_zipCodeTextBoxPlaceholder",  comment: "")
        zipCodeTextField.keyboardType = .NumberPad
        
        searchRadiusField.inputView = UIView(frame: CGRectMake(0, 0, 1, 1))
        searchRadiusField.text = "50 \(NSLocalizedString("Events_searchRadiusUnit", comment: ""))"
        searchRadiusField.addTarget(self, action: "didTapSearchRadius:", forControlEvents: .EditingDidBegin)
        
        searchEventsButton.setTitle(NSLocalizedString("Events_eventSearchButtonTitle", comment: ""), forState: .Normal)
        searchEventsButton.addTarget(self, action: "didTapSearch:", forControlEvents: .TouchUpInside)

        instructionsLabel.textAlignment = .Center
        instructionsLabel.numberOfLines = 0
        noResultsLabel.textAlignment = .Center
        noResultsLabel.text = NSLocalizedString("Events_noEventsFound", comment: "")
        noResultsLabel.lineBreakMode = NSLineBreakMode.ByTruncatingTail;

        resultsTableView.hidden = true
        noResultsLabel.hidden = true
        loadingActivityIndicatorView.hidesWhenStopped = true
        loadingActivityIndicatorView.stopAnimating()

        let inputAccessoryView = UIToolbar(frame: CGRectMake(0, 0, 320, 50))
        inputAccessoryView.barTintColor = self.theme.eventsInputAccessoryBackgroundColor()

        let spacer = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
        let searchButton = UIBarButtonItem(title: NSLocalizedString("Events_eventZipCodeDoneButtonTitle", comment: ""), style: .Done, target: self, action: "didTapSetZipCodeDone:")
        let cancelButton = UIBarButtonItem(title: NSLocalizedString("Events_eventZipCodeCancelButtonTitle", comment: ""), style: .Done, target: self, action: "didTapSetZipCodeCancel:")

        let inputAccessoryItems = [spacer, searchButton, cancelButton]
        inputAccessoryView.items = inputAccessoryItems

        zipCodeTextField.inputAccessoryView = inputAccessoryView
    }

    func applyTheme() {
        zipCodeTextField.textColor = self.theme.eventsZipCodeTextColor()
        zipCodeTextField.font = self.theme.eventsZipCodeFont()
        zipCodeTextField.backgroundColor = self.theme.eventsZipCodeBackgroundColor()
        zipCodeTextField.layer.borderColor = self.theme.eventsZipCodeBorderColor().CGColor
        zipCodeTextField.layer.borderWidth = self.theme.eventsZipCodeBorderWidth()
        zipCodeTextField.layer.cornerRadius = self.theme.eventsZipCodeCornerRadius()
        zipCodeTextField.layer.sublayerTransform = self.theme.eventsZipCodeTextOffset()
        
        //searchRadiusField.textColor = self.theme.eventsDistanceTextColor()
        //searchRadiusField.font = self.theme.eventsDistanceFont()
        searchRadiusField.backgroundColor = self.theme.eventsDistanceBackgroundColor()
        searchRadiusField.layer.borderColor = self.theme.eventsDistanceBorderColor().CGColor
        searchRadiusField.layer.borderWidth = self.theme.eventsDistanceBorderWidth()
        searchRadiusField.layer.cornerRadius = self.theme.eventsDistanceCornerRadius()
        searchRadiusField.layer.sublayerTransform = self.theme.eventsDistanceTextOffset()
        
        //searchEventsButton.setTitleColor(self.theme.eventsSearchButtonTextColor(), forState: .Normal)
        searchEventsButton.backgroundColor = self.theme.eventsSearchButtonColor()
        searchEventsButton.titleLabel!.font = self.theme.eventsSearchButtonFont()
        searchEventsButton.layer.cornerRadius = self.theme.eventsSearchButtonCornerRadius()
        searchEventsButton.titleEdgeInsets.left = self.theme.eventsSearchButtonTitleEdgeInset()
        searchEventsButton.titleEdgeInsets.right = self.theme.eventsSearchButtonTitleEdgeInset()
        
        instructionsLabel.font = theme.eventsInstructionsFont()
        instructionsLabel.textColor = theme.eventsInstructionsTextColor()

        noResultsLabel.textColor = self.theme.eventsNoResultsTextColor()
        noResultsLabel.font = self.theme.eventsNoResultsFont()

        loadingActivityIndicatorView.color = self.theme.defaultSpinnerColor()
    }

    func setupConstraints() {
        let screen = UIScreen.mainScreen().bounds
        
        zipCodeTextField.autoPinEdgeToSuperviewEdge(.Top, withInset: 24)
        zipCodeTextField.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        zipCodeTextField.autoSetDimension(.Height, toSize: 45)
        zipCodeTextField.autoSetDimension(.Width, toSize: screen.width / 3)
        
        searchRadiusField.autoPinEdgeToSuperviewEdge(.Top, withInset: 24)
        searchRadiusField.autoPinEdge(.Left, toEdge: .Right, ofView: zipCodeTextField, withOffset: 8)
        searchRadiusField.autoSetDimension(.Height, toSize: 45)
        searchRadiusField.autoSetDimension(.Width, toSize: screen.width / 3)
        
        searchEventsButton.autoPinEdge(.Left, toEdge: .Right, ofView: searchRadiusField, withOffset: 8)
        searchEventsButton.autoPinEdgeToSuperviewEdge(.Top, withInset: 24)
        searchEventsButton.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        searchEventsButton.autoSetDimension(.Height, toSize: 45)

        instructionsLabel.autoAlignAxisToSuperviewAxis(.Vertical)
        instructionsLabel.autoAlignAxisToSuperviewAxis(.Horizontal)
        instructionsLabel.autoSetDimension(.Width, toSize: 220)

        resultsTableView.autoPinEdge(.Top, toEdge: .Bottom, ofView: zipCodeTextField, withOffset: 8)
        resultsTableView.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero, excludingEdge: .Top)

        noResultsLabel.autoPinEdge(.Top, toEdge: .Bottom, ofView: zipCodeTextField, withOffset: 16)
        noResultsLabel.autoPinEdgeToSuperviewEdge(.Left)
        noResultsLabel.autoPinEdgeToSuperviewEdge(.Right)

        loadingActivityIndicatorView.autoPinEdge(.Top, toEdge: .Bottom, ofView: zipCodeTextField, withOffset: 16)
        loadingActivityIndicatorView.autoAlignAxisToSuperviewAxis(.Vertical)
    }
}
// swiftlint:enable type_body_length
