import "Loggable.sol";
import "FeedBackedCall.sol";
import "TradingAccount.sol";


contract CallSpread is Loggable {

    // Contract status
    bool public             _isActive;
    bool public             _isComplete;

    // Participating addresses and accounts
    address public          _broker;
    address public          _buyer;
    address public          _seller;
    TradingAccount          _buyerAcct;
    TradingAccount          _sellerAcct;

    // Contract legs, i.e., call options
    FeedBackedCall public   _buyerLeg;
    FeedBackedCall public   _sellerLeg;

    // Other information
    uint public             _marginPct;
    uint public             _maxTimeToMaturity;

    function CallSpread() {
        _broker = msg.sender;
        _isActive = false;
        _isComplete = false;
    }

    function initialize(
        address sellerAcct,
        address buyerAcct,
        address sellerLeg,
        address buyerLeg,
        uint    marginPct) returns (bool) {

        // TODO: spawn legs directly from this contract
        _buyerLeg = FeedBackedCall(buyerLeg);
        _sellerLeg = FeedBackedCall(sellerLeg);

        // Percentage difference in value of the legs to be held in escrow
        _marginPct = marginPct;

        // Record the maximum maturity of the legs
        _maxTimeToMaturity = _buyerLeg._timeToMaturity();
        if (_maxTimeToMaturity < _sellerLeg._timeToMaturity()) {
            _maxTimeToMaturity = _sellerLeg._timeToMaturity();
        }

        // Trading accounts
        _buyerAcct = TradingAccount(buyerAcct);
        _buyer = _buyerAcct._owner();
        _sellerAcct = TradingAccount(sellerAcct);
        _seller = _sellerAcct._owner();

        // Authorize trading account of msg.sender
        authorizeTradingAccounts(_maxTimeToMaturity * 3);
    }

    // Authorize trading accounts for margin calls
    function authorizeTradingAccounts(uint buffer) returns (bool) {
        bool buyerAuthed = true;
        bool sellerAuthed = true;

        if (msg.sender == _buyer) {
            buyerAuthed = _buyerAcct.authorize(this,
                                               _maxTimeToMaturity + buffer);
            Authorization(bytes32(address(_buyerAcct)),
                          toText(buyerAuthed));
        }
        if (msg.sender  == _seller) {
            sellerAuthed = _sellerAcct.authorize(this,
                                                 _maxTimeToMaturity + buffer);
            Authorization(bytes32(address(_sellerAcct)),
                          toText(sellerAuthed));
        }
        return (buyerAuthed && sellerAuthed);
    }

    // The receiver validates the contract with the same parameters
    function validate() returns (bool) {
        if (_isActive || _isComplete) {
            return true;
        }
        // Authorize trading account of msg.sender. This is assumed to be
        // the counterparty of the initializer of this contract.
        authorizeTradingAccounts(_maxTimeToMaturity * 3);

        // Need authorized trading accounts
        if (!_buyerAcct.isAuthorized(this) ||
            !_sellerAcct.isAuthorized(this)) {
            return false;
        }

        // Validate the legs
//        if (!_buyerLeg.validate() || !_sellerLeg.validate()) {
//            return false;
//        }

        bool buyerValidated = _buyerLeg.validate();
        Validation(bytes32(address(_buyerLeg)),
                   toText(buyerValidated));
        if (!buyerValidated) {
            return false;
        }

        bool sellerValidated = _sellerLeg.validate();
        Validation(bytes32(address(_sellerLeg)),
                   toText(sellerValidated));
        if (!sellerValidated) {
            return false;
        }

        _isActive = true;
        Validation(bytes32(address(this)),
                   toText(true));
        return true;
    }

    // Withdraw and nullify the contract if not validated
    function withdraw() returns (bool) {
        if (_isActive) {
            return false;
        }
        if (msg.sender != _broker
            && msg.sender != _buyer
            && msg.sender != _seller) {
            return false;
        }
        // Withdraw from both legs
        bool buyerWithdrawn = _buyerLeg.withdraw();
        Withdrawal(bytes32(address(_buyerLeg)),
                   toText(buyerWithdrawn));

        bool sellerWithdrawn = _sellerLeg.withdraw();
        Withdrawal(bytes32(address(_sellerLeg)),
                   toText(sellerWithdrawn));

        // suicide(_broker);
        _broker.send(this.balance);
        _isComplete = true;
        Withdrawal(bytes32(address(this)),
                   toText(true));
        return true;
    }

    // Allow the buyer and seller to exercise their respective options
    function exercise() returns (bool) {
        bool buyerExercised = true;
        bool sellerExercised = true;

        if (msg.sender == _buyer) {
            returnMargin();
            buyerExercised = _buyerLeg.exercise();
            Exercise(bytes32(address(_buyerLeg)),
                     toText(buyerExercised));
        }
        if (msg.sender == _seller) {
            sellerExercised = _sellerLeg.exercise();
            Exercise(bytes32(address(_sellerLeg)),
                     toText(sellerExercised));
        }

        if (_sellerLeg._isComplete() && _buyerLeg._isComplete()) {
            _isActive = false;
            _isComplete = true;
            Exercise(bytes32(address(this)),
                     toText(true));
        }
        return (buyerExercised && sellerExercised);
    }

    // Rebalance the margin based on the current value of the underliers
    function rebalanceMargin() returns (bool) {
        int buyerValue = _buyerLeg.getValue();
        int sellerValue = _sellerLeg.getValue();

        uint difference = uint(buyerValue - sellerValue);
        uint marginAmount = difference * _marginPct / 100;

        if (marginAmount > this.balance) {
            CashFlow(bytes32(address(_sellerAcct)),
                     bytes32(address(this)),
                     bytes32(marginAmount - this.balance));
            _sellerAcct.withdraw(marginAmount - this.balance);
        } else if (marginAmount < this.balance) {
            CashFlow(bytes32(address(this)),
                     bytes32(address(_sellerAcct)),
                     bytes32(this.balance - marginAmount));
            _sellerAcct.deposit.value(this.balance - marginAmount)();
        }

        return this.balance == marginAmount;
    }

    // On maturity, return the escrowed margin to the seller
    function returnMargin() returns (bool) {
        if (_buyerLeg.isMature()) {
            CashFlow(bytes32(address(this)),
                     bytes32(address(_sellerAcct)),
                     bytes32(this.balance));
            return _sellerAcct.deposit.value(this.balance)();
        }
        return false;
    }

    // ===== Utility functions ===== //

    function ping() returns (bool) {
        return rebalanceMargin();
    }
}
