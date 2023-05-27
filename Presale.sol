// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SafeMathInt {
    int256 private constant MIN_INT256 = int256(1) << 255;
    int256 private constant MAX_INT256 = ~(int256(1) << 255);
    function mul(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a * b;
        require(c != MIN_INT256 || (a & MIN_INT256) != (b & MIN_INT256));
        require(b == 0 || c / b == a);
        return c;
    }

    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != -1 || a != MIN_INT256);
        return a / b;
    }

    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a));
        return c;
    }

    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a));
        return c;
    }

    function abs(int256 a) internal pure returns (int256) {
        require(a != MIN_INT256);
        return a < 0 ? -a : a;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "SafeMath: addition overflow");
    return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Presale {
    using SafeMath for uint256;


    //Mainnet
    //IERC20 public usdt = IERC20 (0x55d398326f99059fF775485246999027B3197955);
    //IERC20 public busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    //IERC20 public usdc = IERC20(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d); 
    
    //Testnet
    IERC20 public usdt = IERC20 (0x7ef95a0FEE0Dd31b22626fA2e10Ee6A223F8a684);
    IERC20 public busd = IERC20 (0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7);
    IERC20 public usdc = IERC20 (0x9A06e2E3B6b7d6E1BD451659352b0aA96ca37cA0); // test net
    //IERC20 public usdc = IERC20 (0xd9145CCE52D386f254917e481eB44e9943F39138); // rinkeby

    IERC20 public token;
    bool public paused;
    uint256 public minDeposit = 50000000000000000000; // 50$
    address public owner;
    address public feeReceiver;
    uint256 public perDollarPrice;
    uint256 public totalSold;
    mapping(address => uint256) public userBuy;
    address[] public buyers;
    mapping(address => mapping(address => bool)) public referral;

    modifier onlyOwner() {
        require(owner == msg.sender, "Caller must be the owner");
        _;
    }

    constructor(uint256 _price, address _presaleToken, address _feeReceiver) {
        owner = msg.sender;
        perDollarPrice = _price;
        token = IERC20(_presaleToken);
        feeReceiver = _feeReceiver;
    }

    function allBuyers() public view returns (uint256) {
        return buyers.length;
    }

    function likeBalance(address _user) public view returns (uint256) {
        return token.balanceOf(_user);
    }

    function contractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function remainingToken() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function setTokenPrice(uint256 _price) public onlyOwner {
        perDollarPrice = _price;
    }

    function setPause(bool _value) public onlyOwner {
        paused = _value;
    }

    function setToken(address _token) public onlyOwner {
        token = IERC20(_token);
    }

    function setBusd(address _token) public onlyOwner {
        busd = IERC20(_token);
    }

    function setUsdt(address _token) public onlyOwner {
        usdt = IERC20(_token);
    }

    function setUsdc(address _token) public onlyOwner {
        usdc = IERC20(_token);
    }

    function buyFromToken(uint256 _pid, address payable _ref, uint256 _amount) public payable {
        require(!paused, "Presale is paused");
        uint256 check = 1;
        
        if (_ref == address(0) || _ref == msg.sender || referral[msg.sender][_ref]) {
        } else {
            referral[msg.sender][_ref] = true;
            check = 2;
        }
        
        if (_pid == 1) {
            require(msg.value == _amount, "Invalid amount");
            usdt.transferFrom(msg.sender, address(this), _amount);
            
            if (check == 2) {
                uint256 per5 = (_amount * 5) / 100;
                uint256 per95 = (_amount * 95) / 100;
                usdt.transfer(_ref, per5);
                usdt.transfer(owner, per95);
            } else {
                usdt.transfer(owner, _amount);
            }
            
            uint256 temp = _amount;
            uint256 multiplier = (perDollarPrice * temp) / 10 ** 18;
            
            if (userBuy[msg.sender] == 0) {
                buyers.push(msg.sender);
            }
            
            userBuy[msg.sender] += multiplier;
            // token.transfer(msg.sender, multiplier);
        } else if (_pid == 2) {
            busd.transferFrom(msg.sender, address(this), _amount);
            
            if (check == 2) {
                uint256 per5 = (_amount * 5) / 100;
                uint256 per95 = (_amount * 95) / 100;
                busd.transfer(_ref, per5);
                busd.transfer(owner, per95);
            } else {
                busd.transfer(owner, _amount);
            }
            
            uint256 temp = _amount;
            uint256 multiplier = (perDollarPrice * temp) / 10 ** 18;
            
            if (userBuy[msg.sender] == 0) {
                buyers.push(msg.sender);
            }
            
            userBuy[msg.sender] += multiplier;
            // token.transfer(msg.sender, multiplier);
        } else if (_pid == 3) {
            require(usdc.allowance(msg.sender, address(this)) > 0, "Not enough allowance");
            usdc.transferFrom(msg.sender, address(this), _amount);
            
            if (check == 2) {
                uint256 per5 = (_amount * 5) / 100;
                uint256 per95 = (_amount * 95) / 100;
                usdc.transfer(_ref, per5);
                usdc.transfer(owner, per95);
            } else {
                usdc.transfer(owner, _amount);
            }
            
            uint256 temp = _amount;
            uint256 multiplier = (perDollarPrice * temp) / 10 ** 18;
            
            if (userBuy[msg.sender] == 0) {
                buyers.push(msg.sender);
            }
            
            userBuy[msg.sender] += multiplier;
            // token.transfer(msg.sender, multiplier);
        } else {
            revert("Invalid token selection");
        }
    }

    function releaseToken(address _receiver) public onlyOwner {
        require(userBuy[_receiver] > 0, "Receiver has not bought any tokens");
        userBuy[_receiver] = 0;
        token.transfer(msg.sender, userBuy[_receiver]);
    }

    function rescueTokens(IERC20 _add, uint256 _amount, address _recipient) public onlyOwner {
        _add.transfer(_recipient, _amount);
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    function changeFeeReceiver(address _newReceiver) public onlyOwner {
        feeReceiver = _newReceiver;
    }
}
