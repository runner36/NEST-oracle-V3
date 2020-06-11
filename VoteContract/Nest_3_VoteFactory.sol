pragma solidity 0.6.0;

import "../Lib/SafeMath.sol";

/**
 * @title 投票工厂+ 映射
 * @dev 创建与投票方法
 */
contract Nest_3_VoteFactory {
    using SafeMath for uint256;
    
    uint256 _limitTime = 30 minutes;                                //  投票时间 7
    uint256 _NNLimitTime = 15 minutes;                              //  nestNode筹集时间 1
    uint256 _circulationProportion = 51;                            //  通过票数比例
    uint256 _NNUsedCreate = 10;                                     //  创建投票合约最小nn数量
    uint256 _NNCreateLimit = 100;                                   //  创建投票筹集 NN最小数量
    ERC20 _NNToken;                                                 //  守护者节点token地址
    ERC20 _nestToken;                                               //  NestToken
    mapping(string => address) private _contractAddress;            //  投票合约映射
    mapping(address => bool) _modifyAuthority;                      //  修改权限
    mapping(address => address) _myVote;                            //  我的投票
    bool _stateOfEmergency = false;                                 //  紧急状态
    uint256 _emergencyTime = 0;                                     //  紧急状态启动时间
    uint256 _emergencyTimeLimit = 30 minutes;                       //  紧急状态持续时间
    uint256 _emergencyNNAmount = 1000;                              //  紧急状态需要nn数量
    mapping(address => uint256) _emergencyPerson;                   //  紧急状态个人存储量
    address _destructionAddress;                                    //  销毁合约地址

    event ContractAddress(address contractAddress);
    
    /**
    * @dev 初始化方法
    */
    constructor () public {
        _NNToken = ERC20(checkAddress("nestNode"));
        _destructionAddress = address(checkAddress("nest.v3.destruction"));
        _nestToken = ERC20(address(checkAddress("nest")));
        _modifyAuthority[msg.sender] = true;
    }
    
    /**
    * @dev 重置合约
    */
    function changeMapping() public onlyOwner {
        _NNToken = ERC20(checkAddress("nestNode"));
        _destructionAddress = address(checkAddress("nest.v3.destruction"));
        _nestToken = ERC20(address(checkAddress("nest")));
    }
    
    /**
    * @dev 创建投票合约
    * @param contractAddress 投票可执行合约地址
    * @param nestNodeAmount 质押 NN 数量
    */
    function createVote(address contractAddress, uint256 nestNodeAmount) public {
        require(address(tx.origin) == address(msg.sender), "It can't be a contract");
        require(nestNodeAmount >= _NNUsedCreate);
        Nest_3_VoteContract newContract = new Nest_3_VoteContract(contractAddress, _stateOfEmergency, nestNodeAmount);
        require(_NNToken.transferFrom(address(tx.origin), address(newContract), nestNodeAmount), "Authorization transfer failed");
        addSuperManPrivate(address(newContract));
        emit ContractAddress(address(newContract));
    }
    
    /**
    * @dev 使用 nest 投票
    * @param contractAddress 投票合约地址
    */
    function nestVote(address contractAddress) public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        require(checkOwners(contractAddress) == true, "It's not a voting contract");
        require(checkVoteNow(address(msg.sender)));
        Nest_3_VoteContract newContract = Nest_3_VoteContract(contractAddress);
        newContract.nestVote();
        _myVote[address(tx.origin)] = contractAddress;
    }
    
    /**
    * @dev 使用 nestNode 投票
    * @param contractAddress 投票合约地址
    * @param NNAmount 质押 NN 数量
    */
    function nestNodeVote(address contractAddress, uint256 NNAmount) public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        Nest_3_VoteContract newContract = Nest_3_VoteContract(contractAddress);
        require(_NNToken.transferFrom(address(tx.origin), address(newContract), NNAmount), "Authorization transfer failed");
        newContract.nestNodeVote(NNAmount);
    }
    
    /**
    * @dev 查看是否有正在参与的投票 
    * @param user 参与投票地址
    * @return bool 是否正在参与投票
    */
    function checkVoteNow(address user) public view returns(bool) {
        if (_myVote[user] == address(0x0)) {
            return true;
        } else {
            Nest_3_VoteContract vote = Nest_3_VoteContract(_myVote[user]);
            if (vote.checkContractEffective() || vote.checkPersonalAmount(user) == 0) {
                return true;
            }
            return false;
        }
    }
    
    /**
    * @dev 查看我的投票
    * @param user 参与投票地址
    * @return address 最近参与的投票合约地址
    */
    function checkMyVote(address user) public view returns (address) {
        return _myVote[user];
    }
    
    /**
    * @dev 查看投票时间
    */
    function checkLimitTime() public view returns(uint256) {
        return _limitTime;
    }
    
    /**
    * @dev 查看nestNode筹集时间
    */
    function checkNNLimitTime() public view returns(uint256) {
        return _NNLimitTime;
    }
    
    /**
    * @dev 查看通过投票比例
    */
    function checkCirculationProportion() public view returns(uint256) {
        return _circulationProportion;
    }
    
    /**
    * @dev 查看创建投票合约最小nn数量
    */
    function checkNNUsedCreate() public view returns(uint256) {
        return _NNUsedCreate;
    }
    
    /**
    * @dev 查看创建投票筹集 NN最小数量
    */
    function checkNNCreateLimit() public view returns(uint256) {
        return _NNCreateLimit;
    }
    
    /**
    * @dev 查看是否是紧急状态 
    */
    function checkStateOfEmergency() public view returns(bool){
        return _stateOfEmergency;
    }
    
    /**
    * @dev 修改投票时间
    */
    function changeLimitTime(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _limitTime = num;
    }
    
    /**
    * @dev 修改nestNode筹集时间
    */
    function changeNNLimitTime(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _NNLimitTime = num;
    }
    
    /**
    * @dev 修改通过投票比例
    */
    function changeCirculationProportion(uint256 num) public onlyOwner {
        require(num > 0, "Parameter needs to be greater than 0");
        _circulationProportion = num;
    }
    
    /**
    * @dev 修改创建投票合约最小nn数量
    */
    function changeNNUsedCreate(uint256 num) public onlyOwner {
        _NNUsedCreate = num;
    }
    
    /**
    * @dev 修改创建投票筹集 NN最小数量
    */
    function checkNNCreateLimit(uint256 num) public onlyOwner {
        _NNCreateLimit = num;
    }
    
    //  转入nn
    function sendNestNode(uint256 amount) public {
        require(_NNToken.transferFrom(address(tx.origin), address(this), amount));
        _emergencyPerson[address(tx.origin)] = _emergencyPerson[address(tx.origin)].add(amount);
    }
    
    //  取出nn
    function turnOutNestNode() public {
        require(_emergencyPerson[address(tx.origin)] > 0);
        require(_NNToken.transfer(address(tx.origin), _emergencyPerson[address(tx.origin)]));
        _emergencyPerson[address(tx.origin)] = 0;
        //  销毁 NEST
        uint256 nestAmount = _nestToken.balanceOf(address(this));
        require(_nestToken.transfer(address(_destructionAddress), nestAmount));
    }
    
    /**
    * @dev 修改紧急状态
    */
    function changeStateOfEmergency() public {
        if (_stateOfEmergency == false) {
            require(_emergencyPerson[address(msg.sender)] > 0);
            require(_NNToken.balanceOf(address(this)) >= _emergencyNNAmount);
            _stateOfEmergency = true;
            _emergencyTime = now;
        } else {
            require(now > _emergencyTime.add(_emergencyTimeLimit));
            _stateOfEmergency = false;
            _emergencyTime = 0;
        }
    }
    
    //  查看紧急状态启动时间 
    function checkEmergencyTime() public view returns (uint256) {
        return _emergencyTime;
    }
    
    //  查看紧急状态持续时间 
    function checkEmergencyTimeLimit() public view returns(uint256) {
        return _emergencyTimeLimit;
    }
    
    //  查看个人NN存储量
    function checkEmergencyPerson(address user) public view returns(uint256) {
        return _emergencyPerson[user];
    }
    
    //  查看紧急状态需要nn数量
    function checkEmergencyNNAmount() public view returns(uint256) {
        return _emergencyNNAmount;
    }
    
    //  修改紧急状态持续时间
    function changeEmergencyTimeLimit(uint256 num) public onlyOwner {
        require(num > 0);
        _emergencyTimeLimit = num.mul(1 days);
    }
    
    //  修改紧急状态需要nn数量
    function changeEmergencyNNAmount(uint256 num) public onlyOwner {
        require(num > 0);
        _emergencyNNAmount = num;
    }
    
    //  查询地址
    function checkAddress(string memory name) public view returns (address contractAddress) {
        return _contractAddress[name];
    }
    
    //  添加合约映射地址
    function addContractAddress(string memory name, address contractAddress) public onlyOwner{
        _contractAddress[name] = contractAddress;
    }
    
    //  增加管理地址
    function addSuperMan(address superMan) public onlyOwner{
        _modifyAuthority[superMan] = true;
    }
    function addSuperManPrivate(address superMan) private {
        _modifyAuthority[superMan] = true;
    }
    
    //  删除管理地址
    function deleteSuperMan(address superMan) public onlyOwner{
        _modifyAuthority[superMan] = false;
    }
    
    //  查看是否管理员
    function checkOwners(address man) public view returns (bool){
        return _modifyAuthority[man];
    }
    
    //  仅限管理员操作
    modifier onlyOwner(){
        require(checkOwners(msg.sender) == true, "No authority");
        _;
    }
}

/**
 * @title 投票合约
 */
contract Nest_3_VoteContract {
    using SafeMath for uint256;
    
    Nest_3_MiningSave _miningSave;                      //  矿池合约
    Nest_3_Implement _implementContract;                //  可执行合约
    Nest_3_NestSave _nestSave;                          //  锁仓合约 
    Nest_3_VoteFactory _voteFactory;                    //  投票工厂合约
    Nest_3_NestAbonus _nestAbonus;                      //  分红逻辑合约
    ERC20 _nestToken;                                   //  nestToken
    ERC20 _NNToken;                                     //  守护者节点
    address _implementAddress;                          //  执行地址
    address _destructionAddress;                        //  销毁合约地址
    uint256 _createTime;                                //  创建时间
    uint256 _endTime;                                   //  结束时间
    uint256 _totalAmount;                               //  总投票数
    uint256 _circulation;                               //  通过票数
    uint256 _destroyedNest = 0;                         //  已销毁 NEST
    uint256 _NNLimitTime;                               //  nestNode筹集时间
    uint256 _NNCreateLimit;                             //  创建投票筹集 NN最小数量
    bool _effective = false;                            //  是否生效
    bool _stateOfEmergency;                             //  是否为紧急状态 
    mapping(address => uint256) _personalAmount;        //  个人投票数
    mapping(address => uint256) _personalNNAmount;      //  NN个人投票数
    uint256 _allNNAmount;                               //  NN总数
    bool _nestVote = false;                             //  是否可进行nest投票
    bool _isChange = false;                             //  是否已执行
    
    /**
    * @dev 初始化方法
    * @param contractAddress 可执行合约地址
    * @param stateOfEmergency 是否为紧急状态 
    * @param NNAmount NN数量
    */
    constructor (address contractAddress, bool stateOfEmergency, uint256 NNAmount) public {
        //  初始化
        _voteFactory = Nest_3_VoteFactory(address(msg.sender));
        _nestToken = ERC20(_voteFactory.checkAddress("nest"));
        _NNToken = ERC20(_voteFactory.checkAddress("nestNode"));
        _implementContract = Nest_3_Implement(address(contractAddress));
        _implementAddress = address(contractAddress);
        _destructionAddress = address(_voteFactory.checkAddress("nest.v3.destruction"));
        _personalNNAmount[address(tx.origin)] = NNAmount;
        _allNNAmount = NNAmount;
        _createTime = now;                                    
        _endTime = _createTime.add(_voteFactory.checkLimitTime());
        _NNLimitTime = _voteFactory.checkNNLimitTime();
        _NNCreateLimit = _voteFactory.checkNNCreateLimit();
        _stateOfEmergency = stateOfEmergency;
        if (_stateOfEmergency == false) {
            _miningSave = Nest_3_MiningSave(_voteFactory.checkAddress("nest.v3.miningSave"));
            _nestSave = Nest_3_NestSave(_voteFactory.checkAddress("nest.v3.nestSave"));
            _circulation = (uint256(10000000000 ether).sub(_nestToken.balanceOf(address(_miningSave))).sub(_nestToken.balanceOf(address(_destructionAddress)))).mul(_voteFactory.checkCirculationProportion()).div(100);
        } else {
            _nestAbonus = Nest_3_NestAbonus(_voteFactory.checkAddress("nest.v3.nestAbonus"));
            _circulation = _nestAbonus.checkAllValueMapping(2).mul(_voteFactory.checkCirculationProportion()).div(100);
        }
        if (_allNNAmount >= _NNCreateLimit) {
            _nestVote = true;
        }
    }
    
    /**
    * @dev  NEST投票
    */
    function nestVote() public onlyFactory {
        require(now <= _endTime, "Voting time exceeded");
        require(_effective == false, "Vote in force");
        require(_personalAmount[address(tx.origin)] == 0, "Have voted");
        uint256 amount;
        if (_stateOfEmergency == false) {
            amount = _nestSave.checkAmount(address(tx.origin));
        } else {
            amount = _nestAbonus.checkNestMapping(2, address(tx.origin));
        }
        _personalAmount[address(tx.origin)] = amount;
        _totalAmount = _totalAmount.add(amount);
        ifEffective();
    }
    
    /**
    * @dev NEST取消投票
    */
    function nestVoteCancel() public {
        require(address(msg.sender) == address(tx.origin), "It can't be a contract");
        require(now <= _endTime, "Voting time exceeded");
        require(_effective == false, "Vote in force");
        require(_personalAmount[address(msg.sender)] > 0, "No vote");                     
        _totalAmount = _totalAmount.sub(_personalAmount[address(msg.sender)]);
        _personalAmount[address(msg.sender)] = 0;
    }
    
    /**
    * @dev  NestNode投票
    * @param NNAmount NN数量
    */
    function nestNodeVote(uint256 NNAmount) public onlyFactory {
        require(now <= _createTime.add(_NNLimitTime), "Voting time exceeded");
        require(_nestVote == false);
        _personalNNAmount[address(tx.origin)] = _personalNNAmount[address(tx.origin)].add(NNAmount);
        _allNNAmount = _allNNAmount.add(NNAmount);
        if (_allNNAmount >= _NNCreateLimit) {
            _nestVote = true;
        }
    }
    
    /**
    * @dev 取出抵押 NN
    */
    function turnOutNestNode() public {
        if (_nestVote) {
            //  正常nest投票
            if (_stateOfEmergency == false || (_stateOfEmergency && _effective == false)) {
                //  非紧急状态
                require(now > _endTime, "Vote unenforceable");
            }
        } else {
            //  nn投票
            require(now > _createTime.add(_NNLimitTime));
        }
        require(_personalNNAmount[address(msg.sender)] > 0);
        //  转回NN
        require(_NNToken.transfer(address(msg.sender), _personalNNAmount[address(msg.sender)]));
        _personalNNAmount[address(msg.sender)] = 0;
        //  销毁 NEST
        uint256 nestAmount = _nestToken.balanceOf(address(this));
        _destroyedNest = _destroyedNest.add(nestAmount);
        require(_nestToken.transfer(address(_destructionAddress), nestAmount));
    }
    
    /**
    * @dev 执行修改合约
    */
    function startChange() public {
        require(!_isChange);
        if (_stateOfEmergency == false) {
            require(_effective && now > _endTime, "Vote unenforceable");
        } else {
            require(_effective, "Vote unenforceable");
        }
        //  将执行合约加入管理集合
        _voteFactory.addSuperMan(address(_implementContract));
        //  执行
        _implementContract.doit();
        //  将执行合约删除
        _voteFactory.deleteSuperMan(address(_implementContract));
        _isChange = true;
    }
    
    /**
    * @dev 判断是否生效
    */
    function ifEffective() private {
        if (_totalAmount > _circulation) {
            _effective = true;
        }
    }
    
    /**
    * @dev 查看投票合约是否结束
    */
    function checkContractEffective() public view returns(bool) {
        if (_effective || now > _endTime) {
            return true;
        } 
        return false;
    }
    
    //  查看执行合约地址 
    function checkImplementAddress() public view returns(address) {
        return _implementAddress;
    }
    
    //  查看投票开始时间
    function checkCreateTime() public view returns(uint256) {
        return _createTime;
    }
    
    //  查看投票结束时间
    function checkEndTime() public view returns(uint256) {
        return _endTime;
    }
    
    //  查看当前总投票数
    function checkTotalAmount() public view returns(uint256) {
        return _totalAmount;
    }
    
    //  查看通过投票数
    function checkCirculation() public view returns(uint256) {
        return _circulation;
    }
    
    //  查看个人投票数
    function checkPersonalAmount(address user) public view returns(uint256) {
        return _personalAmount[user];
    }
    
    //  查看已经销毁NEST
    function checkDestroyedNest() public view returns(uint256) {
        return _destroyedNest;
    }
    
    //  查看合约是否生效
    function checkEffective() public view returns(bool) {
        return _effective;
    }
    
    //  查看是否是紧急状态 
    function checkStateOfEmergency() public view returns(bool){
        return _stateOfEmergency;
    }
    
    //  查看nestNode筹集时间
    function checkNNLimitTime() public view returns(uint256) {
        return _NNLimitTime;
    }
    
    //  查看创建投票筹集 NN最小数量
    function checkNNCreateLimit() public view returns(uint256) {
        return _NNCreateLimit;
    }
    
    //  查看NN个人投票数
    function checkPersonalNNAmount(address user) public view returns(uint256) {
        return _personalNNAmount[address(user)];
    }
    
    //  查看NN总数
    function checkAllNNAmount() public view returns(uint256) {
        return _allNNAmount;
    }
    
    //  查看是否可进行nest投票
    function checkNestVote() public view returns(bool) {
        return _nestVote;
    }
    
    //  查看是否已执行
    function checkIsChange() public view returns(bool) {
        return _isChange;
    }
    
    //  仅限工厂合约
    modifier onlyFactory(){
        require(address(_voteFactory) == address(msg.sender), "No authority");
        _;
    }
}

interface Nest_3_Implement {
    //  执行
    function doit() external;
}

//  矿池合约
interface Nest_3_MiningSave {
    //  查询矿池余额
    function checkNestBalance() external view returns(uint256);
}

//  nest锁仓合约
interface Nest_3_NestSave {
    //  查看锁仓金额
    function checkAmount(address sender) external view returns(uint256);
}

//  分红逻辑合约
interface Nest_3_NestAbonus {
    //  查看nest流通量快照
    function checkAllValueMapping(uint256 times) external view returns(uint256);
    //  查看nest流通量快照
    function checkNestMapping(uint256 times, address user) external view returns(uint256);
}

interface ERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}