// SPDX-License-Identifier: MIT
// 소스 코드가 MIT 라이선스로 제공됨을 명시

pragma solidity ^0.8.0;
// Solidity 버전 0.8.0 이상을 사용

// 경매 컨트랙트 정의
contract Auction {

    // 경매 소유자의 주소 (배포자가 이 주소가 됨) *internal: 외부 접근 불가 / 상속 가능
    address internal auction_owner;

    // 경매 시작 시간을 저장하는 변수
    uint256 public auction_start;

    // 경매 종료 시간을 저장하는 변수
    uint256 public auction_end;

    // 현재 최고 입찰가를 저장하는 변수
    uint256 public highestBid;

    // 현재 최고 입찰자의 주소를 저장하는 변수
    address public highestBidder;

    // 경매 상태를 나타내는 enum. CANCELLED(취소됨)과 STARTED(시작됨) 상태를 가짐
    enum auction_state {
        CANCELLED, STARTED
    }

    // 자동차 정보를 저장하는 구조체 정의
    struct car {
        // 자동차 브랜드 (예: 현대)
        string Brand;

        // 자동차 번호판 (예: 61거 1234)
        string Rnumber;
    }

    // 경매 중인 자동차 정보 저장
    car public Mycar;

    // 입찰자들의 주소를 저장하는 배열
    address[] bidders;

    // 입찰자의 주소별로 입찰 금액을 매핑 (지갑 주소 -> 입찰 금액)
    mapping(address => uint) public bids;

    // 경매 상태를 저장하는 변수, enum 타입의 상태값을 가짐
    auction_state public STATE;

    // 경매가 아직 진행 중인지 확인하는 modifier
    modifier an_ongoing_auction() {
        // 경매 종료 시간이 현재 시간보다 크거나 같아야 함 (경매가 끝나지 않았을 경우)
        require(block.timestamp <= auction_end, "Auction has ended");
        _;
    }

    // 경매 소유자만 해당 함수에 접근할 수 있게 하는 modifier
    modifier only_owner() {
        // 호출자의 주소가 경매 소유자 주소와 일치하는지 확인
        require(msg.sender == auction_owner, "Only auction owner can call this");
        _;
    }

    // 입찰 함수, 나중에 override(재정의)할 예정, virtual을 사용하여 재정의 가능
    function bid() public payable virtual returns (bool) {}

    // 출금 함수, 나중에 override(재정의)할 예정
    function withdraw() public virtual returns (bool) {}

    // 경매 취소 함수, 나중에 override(재정의)할 예정
    function cancel_auction() external virtual returns (bool) {}

    // 입찰 이벤트, 입찰자가 입찰했을 때 호출됨
    event BidEvent(address indexed highestBidder, uint256 highestBid);

    // 출금 이벤트, 출금했을 때 호출됨
    event WithdrawalEvent(address withdrawer, uint256 amount);

    // 경매 취소 이벤트, 경매가 취소되었을 때 호출됨
    event CanceledEvent(uint message, uint256 time);

    // 경매 상태가 업데이트될 때 호출되는 이벤트
    event StateUpdated(auction_state newState);
}

// MyAuction 컨트랙트 정의, Auction 컨트랙트를 상속받음
contract MyAuction is Auction {

    // 생성자, 경매 소유자, 경매 시간, 자동차 정보 설정
    constructor(uint _biddingTime, address _owner, string memory _brand, string memory _Rnumber) {
        // 경매 소유자를 설정
        auction_owner = _owner;

        // 경매 시작 시간을 현재 시간으로 설정
        auction_start = block.timestamp;

        // 경매 종료 시간을 입찰 시간만큼 더한 값으로 설정 (시간 단위로)
        auction_end = auction_start + _biddingTime * 1 hours;

        // 경매 상태를 시작됨으로 설정
        STATE = auction_state.STARTED;

        // 자동차 정보를 설정
        Mycar.Brand = _brand;
        Mycar.Rnumber = _Rnumber;
    }

    // 입찰 함수 재정의 (override)
    function bid() public payable override an_ongoing_auction returns (bool) {
        // 입찰자가 이전 입찰 금액 + 현재 입찰 금액이 최고 입찰 금액보다 큰지 확인
        require(bids[msg.sender] + msg.value > highestBid, "You can't bid, make a higher bid");

        // 최고 입찰자의 주소를 현재 입찰자로 업데이트
        highestBidder = msg.sender;

        // 최고 입찰 금액을 현재 입찰 금액으로 업데이트
        highestBid = msg.value;

        // 입찰자를 입찰자 목록에 추가
        bidders.push(msg.sender);

        // 해당 입찰자의 입찰 금액을 업데이트
        bids[msg.sender] = bids[msg.sender] + msg.value;

        // 입찰 이벤트 호출
        emit BidEvent(highestBidder, highestBid);

        return true;
    }

    // 경매 취소 함수 재정의 (override)
    function cancel_auction() external override only_owner an_ongoing_auction returns (bool) {
        // 경매 상태를 취소됨으로 업데이트
        STATE = auction_state.CANCELLED;

        // 경매 취소 이벤트 호출
        emit CanceledEvent(1, block.timestamp);
        return true;
    }

    // 경매 비활성화 함수, 경매 종료 후 호출 가능
    function deactivateAuction() external only_owner {
        // 경매가 종료되었는지 확인
        require(block.timestamp > auction_end, "Auction is still ongoing");

        // 경매 상태를 취소됨으로 설정
        STATE = auction_state.CANCELLED;

        // 경매 취소 이벤트 호출
        emit CanceledEvent(2, block.timestamp);
    }

    // 경매 소유자가 남은 자금을 회수하는 함수
    function withdrawRemainingFunds() external only_owner {
        // 계약 잔액 확인
        uint balance = address(this).balance;
        require(balance > 0, "No funds left in the contract");

        // 소유자에게 잔액 전송
        (bool success, ) = payable(auction_owner).call{value: balance}("");
        require(success, "Transfer failed");
    }

    // 입찰자가 자신의 입찰 금액을 출금하는 함수 재정의
    function withdraw() public override returns (bool) {
        // 입찰자의 입찰 금액 확인
        uint amount = bids[msg.sender];
        require(amount > 0, "No funds to withdraw");

        // 입찰 금액을 0으로 설정
        bids[msg.sender] = 0;

        // 입찰자에게 금액 전송
        (bool success, ) = payable(msg.sender).call{value: amount, gas: 5000}("");
        require(success, "Transfer failed");

        // 출금 이벤트 호출
        emit WithdrawalEvent(msg.sender, amount);
        return true;
    }

    // 경매 소유자의 주소를 반환하는 함수
    function get_owner() public view returns (address) {
        return auction_owner;
    }

    // 경매 상태를 업데이트하는 함수
    function updateAuctionState(auction_state newState) external only_owner {
        // 새로운 경매 상태로 업데이트
        STATE = newState;

        // 상태 업데이트 이벤트 호출
        emit StateUpdated(newState);
    }
}
