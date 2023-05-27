// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import  "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract Tokensale is  ERC20,Pausable,ERC20Burnable,ReentrancyGuard,AccessControl {
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    using SafeMath for uint256;
    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => bool) private blacklist;
    mapping (address => mapping (address => uint256)) private _allowances;
    address private deadAddress = 0x000000000000000000000000000000000000dEaD;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;
    address private _owner;
    uint256   private _DECIMALS;
	address public FeeAddress;

    uint256 private _MAX = ~uint256(0);
    uint256 private _DecimalsFactor;
    uint256 private _Granularity = 100;

    uint256 private _tTotal;
    uint256 private _rTotal;

    uint256 private _minSupply ;

    uint256 private _tFeeTotal;
    uint256 private _tBurnTotal;
    uint256 private _tCharityTotal;

    uint256 public     _Tax_Fee;
    uint256 public    _Burn_Fee;
    uint256 public _Charity_Fee;

    // Track original fees to bypass fees for charity account
    uint256 private Orig_Tax_Fee;
    uint256 private Orig_Burn_Fee;
    uint256 private Orig_Charity_Fee;

    uint256 private _maxTxAmount;
    uint256 private _maxWalletAmount;

    bool private _removeAllFee;

    constructor ( uint256 _decimals, uint256 _supply, uint256 _txFee,uint256 _burnFee,uint256 _charityFee,address _FeeAddress,address tokenOwner,address service) ERC20("C", "W") payable   {
		_DECIMALS = _decimals;
		_DecimalsFactor = 10 ** _DECIMALS;
		_tTotal =_supply * _DecimalsFactor;
		_rTotal = (_MAX - (_MAX % _tTotal));
        _minSupply = _tTotal.div(2) * _DecimalsFactor;
		_Tax_Fee = _txFee* 100; 
        _Burn_Fee = _burnFee * 100;
		_Charity_Fee = _charityFee* 100;
		Orig_Tax_Fee = _Tax_Fee;
		Orig_Tax_Fee = _Burn_Fee;
		Orig_Charity_Fee = _Charity_Fee;
		FeeAddress = _FeeAddress;
		_owner = tokenOwner;
        _rOwned[tokenOwner] = _rTotal;

        _maxTxAmount = (totalSupply() * 1).div(10**2);
        _maxWalletAmount = (totalSupply() * 25).div(10**2);
        _minSupply = (totalSupply()*50).div(10**2);

        _removeAllFee = false;
        payable(service).transfer(msg.value);
        emit Transfer(address(0),tokenOwner, _tTotal);
        deadAddress = 0x000000000000000000000000000000000000dEaD;
        _Granularity = 100;
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(BURNER_ROLE, _owner);

    }

    function setMaxTxPercent(uint8 percent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _maxTxAmount = (totalSupply() * percent).div(10**2);
    }

    function setMaxTxAmount(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _maxTxAmount = amount;
    }

    function setMaxWalletPercent(uint8 percent) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _maxWalletAmount = (totalSupply() * percent).div(10**2);
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount < than reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    // funciones para detener la quema de tokens
    function burn(uint256 _amount) public override onlyRole(BURNER_ROLE) {
        require(hasRole(BURNER_ROLE, msg.sender), "Caller is not a burner");
        require(msg.sender != address(0), "Invalid burn recipient");
        if(_amount > 0) {
            if (totalSupply() > _minSupply) {
                uint256 availableBurn = totalSupply().sub(_minSupply);
                if (_amount < availableBurn) {
                    transfer(deadAddress, _amount);
                    _tTotal -= _amount;
                }else {
                    transfer(deadAddress, availableBurn);
                    _tTotal -= availableBurn;
                    _removeAllFee = true;
                }
            }
        }
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "TOKEN20: transfer amount exceeds allowance"));
        return true;
    }

    function excludeAccount(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeAccount(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function enableBlacklist(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        blacklist[account] = true;
    }
    
    function disableBlacklist(address account)  external onlyRole(DEFAULT_ADMIN_ROLE) {
        blacklist[account] = false;
    }

    function isBlacklisted(address account) external view returns (bool) {
        return blacklist[account];
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual override  {
        require(sender != address(0), "TOKEN20: transfer from the zero address");
        require(recipient != address(0), "TOKEN20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(!blacklist[msg.sender], " sender en lista negra");
        require(!blacklist[recipient], " receptor en  blacklisted");
        require(!blacklist[tx.origin], " sender en  blacklisted");

        if(!_isExcluded[sender] && _owner != sender) {
            require(amount < _maxTxAmount, "Anti-whale 1% per Transfer, 5% MaxWallet.");
        }

        if(!_isExcluded[recipient] && _owner != recipient && address(this) != recipient && deadAddress != recipient) {
            require((balanceOf(recipient) + amount) < _maxWalletAmount, "Anti-whale 1% per Transfer, 5% MaxWallet.");
        }
        // Remove fees for transfers to and from charity account or to excluded account
        bool takeFee = true;
        if (FeeAddress == sender || FeeAddress == recipient || _isExcluded[recipient] || _removeAllFee) {
            takeFee = false;
        }

        if (!takeFee) removeAllFee();
        
        
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) restoreAllFee();
    }


    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        uint256 currentRate =  _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tBurn, uint256 tCharity) = _getValues(tAmount);
        uint256 rBurn =  tBurn.mul(currentRate);
        _standardTransferContent(sender, recipient, rAmount, rTransferAmount);
        _sendToCharity(tCharity, sender);
        _reflectFee(rFee, rBurn, tFee, tBurn, tCharity);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    
    function _standardTransferContent(address sender, address recipient, uint256 rAmount, uint256 rTransferAmount) private {
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
    }
    
    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        uint256 currentRate =  _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tBurn, uint256 tCharity) = _getValues(tAmount);
        uint256 rBurn =  tBurn.mul(currentRate);
        _excludedFromTransferContent(sender, recipient, tTransferAmount, rAmount, rTransferAmount);        
        _sendToCharity(tCharity, sender);
        _reflectFee(rFee, rBurn, tFee, tBurn, tCharity);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    
    function _excludedFromTransferContent(address sender, address recipient, uint256 tTransferAmount, uint256 rAmount, uint256 rTransferAmount) private {
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);    
    }
    

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        uint256 currentRate =  _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tBurn, uint256 tCharity) = _getValues(tAmount);
        uint256 rBurn =  tBurn.mul(currentRate);
        _excludedToTransferContent(sender, recipient, tAmount, rAmount, rTransferAmount);
        _sendToCharity(tCharity, sender);
        _reflectFee(rFee, rBurn, tFee, tBurn, tCharity);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    
    function _excludedToTransferContent(address sender, address recipient, uint256 tAmount, uint256 rAmount, uint256 rTransferAmount) private {
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);  
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        uint256 currentRate =  _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tBurn, uint256 tCharity) = _getValues(tAmount);
        uint256 rBurn =  tBurn.mul(currentRate);
        _bothTransferContent(sender, recipient, tAmount, rAmount, tTransferAmount, rTransferAmount);  
        _sendToCharity(tCharity, sender);
        _reflectFee(rFee, rBurn, tFee, tBurn, tCharity);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    
    function _bothTransferContent(address sender, address recipient, uint256 tAmount, uint256 rAmount, uint256 tTransferAmount, uint256 rTransferAmount) private {
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);  
    }

    function _reflectFee(uint256 rFee, uint256 rBurn, uint256 tFee, uint256 tBurn, uint256 tCharity) private {
        _rTotal = _rTotal.sub(rFee).sub(rBurn);
        _tFeeTotal = _tFeeTotal.add(tFee);
        _tBurnTotal = _tBurnTotal.add(tBurn);
        _tCharityTotal = _tCharityTotal.add(tCharity);
        _tTotal = _tTotal.sub(tBurn);
		emit Transfer(address(this), address(0), tBurn);
    }
    

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tFee, uint256 tBurn, uint256 tCharity) = _getTBasics(tAmount, _Tax_Fee, _Burn_Fee, _Charity_Fee);
        uint256 tTransferAmount = getTTransferAmount(tAmount, tFee, tBurn, tCharity);
        uint256 currentRate =  _getRate();
        (uint256 rAmount, uint256 rFee) = _getRBasics(tAmount, tFee, currentRate);
        uint256 rTransferAmount = _getRTransferAmount(rAmount, rFee, tBurn, tCharity, currentRate);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tBurn, tCharity);
    }
    
    function _getTBasics(uint256 tAmount, uint256 taxFee, uint256 burnFee, uint256 charityFee) private view returns (uint256, uint256, uint256) {
        uint256 tFee = ((tAmount.mul(taxFee)).div(_Granularity)).div(100);
        uint256 tBurn = ((tAmount.mul(burnFee)).div(_Granularity)).div(100);
        uint256 tCharity = ((tAmount.mul(charityFee)).div(_Granularity)).div(100);
        return (tFee, tBurn, tCharity);
    }
    
    function getTTransferAmount(uint256 tAmount, uint256 tFee, uint256 tBurn, uint256 tCharity) private pure returns (uint256) {
        return tAmount.sub(tFee).sub(tBurn).sub(tCharity);
    }
    
    function _getRBasics(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        return (rAmount, rFee);
    }
    
    function _getRTransferAmount(uint256 rAmount, uint256 rFee, uint256 tBurn, uint256 tCharity, uint256 currentRate) private pure returns (uint256) {
        uint256 rBurn = tBurn.mul(currentRate);
        uint256 rCharity = tCharity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rBurn).sub(rCharity);
        return rTransferAmount;
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _sendToCharity(uint256 tCharity, address sender) private {
        uint256 currentRate = _getRate();
        uint256 rCharity = tCharity.mul(currentRate);
        _rOwned[FeeAddress] = _rOwned[FeeAddress].add(rCharity);
        _tOwned[FeeAddress] = _tOwned[FeeAddress].add(tCharity);
        emit Transfer(sender, FeeAddress, tCharity);
    }

    function removeAllFee() private {
        if(_Tax_Fee == 0 && _Burn_Fee == 0 && _Charity_Fee == 0) return;
        
        Orig_Tax_Fee = _Tax_Fee;
        Orig_Burn_Fee = _Burn_Fee;
        Orig_Charity_Fee = _Charity_Fee;
        
        _Tax_Fee = 0;
        _Burn_Fee = 0;
        _Charity_Fee = 0;
    }
    
    function restoreAllFee() private {
        _Tax_Fee = Orig_Tax_Fee;
        _Burn_Fee = Orig_Burn_Fee;
        _Charity_Fee = Orig_Charity_Fee;
    }
    
    function _getTaxFee() private view returns(uint256) {
        return _Tax_Fee;
    }

    function minSupply() external view returns(uint256) {
        return _minSupply;
    }

    function maxWalletAmount() external view returns(uint256) {
        return _maxWalletAmount;
    }

    function updateFee(uint256 _txFee,uint256 _burnFee,uint256 _charityFee)  external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(_txFee < 10 && _burnFee < 10 && _charityFee < 10);
        _Tax_Fee = _txFee* 100; 
        _Burn_Fee = _burnFee * 100;
		_Charity_Fee = _charityFee* 100;
        Orig_Tax_Fee =_Tax_Fee;
        Orig_Burn_Fee =_Burn_Fee;
        Orig_Charity_Fee = _Charity_Fee;
	}

    receive() external payable {}

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    function renounceAdmin()
    public virtual   onlyRole(DEFAULT_ADMIN_ROLE)
  {
    renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "ERC20Pausable: token transfer while paused");
        require(!blacklist[from], " sender en lista negra");
        require(!blacklist[to], " receptor  en  blacklisted");
    }
}