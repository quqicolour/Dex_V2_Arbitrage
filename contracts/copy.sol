//SPDX-License-Identifier:MIT
pragma solidity >=0.7.6;
pragma abicoder v2;

import {SafeMath} from "../libraries/SafeMath.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";
import { IERC20 } from "../interfaces/IERC20.sol";

//uni v3
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

/*  
mumbai:
    * matic:0x02E1A80D80c3F1DE3492C14ce391ba94823E39F8
    * usdt:0x2F6Ec96e6c64a910f5199CDF7Ad9a8456b254f99

    * zh-matic:0x16024b374d4b83534D28785825bA7a51bcCdB18e
    * zh-usdc: 0xF57A63527E8B03e0cd40a050f850a797018BFfee
    * univ3 fee:0.3% 3000

    sushiRouter:0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
    quickRouter:0x8954AfA98594b838bda56FE4C12a09D7739D179b

    sushiFactory:0xc35DADB65012eC5796536bD9864eD8773aBc74C4
    quickFactory:0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32

    quick pair:0x4A56a1213b8442d147Fe55cE4AfD3DB6612156E0
    sushi pair:0x2f458C0e872Bcc2f15AB96b0214D139b608ef050
    univ3 pair:0xC41fEa7dF90DD9fF0ea2c53C66733A80A7b3cfBe
    *时间戳:>1994914681
ganache_fork_mainnet:
    * matic:0xF201c33F48AdaEA96D6aaEcec87d5c218d6cA97B
    * usdt:0xfa5dCFcE9874f3bd34d3a9c8E4C52E5Abe3876FD
    * zh-matic:
    * zh-usdc:

    sushiRouter:0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F
    uniV2Router:0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D 

    sushiFactory:0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac
    uniV2Factory:0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f 

    uniV3Factory:0x1F98431c8aD98523631AE4a59f267346ea31F984
    swapRouter:0xE592427A0AEce92De3Edee1F18E0157C05861564	

    sushi pair:0xF828830D2140288098f73044B5Af1923dDDfCD53
    uniV2 pair:0xf5B44cee1842606749A0338702C4C4228354F81B
    uniV3 pair: fee:3000
    *时间戳:>1794995656
    
*/

contract DexArbitrage{
    using SafeMath for uint256;
    address private _ThisOwner;

    IUniswapV2Factory factory1;
    IUniswapV2Factory factory2;
    IUniswapV2Factory factory3;

    IUniswapV2Router02 router1;
    IUniswapV2Router02 router2;
    IUniswapV2Router02 router3;

    ISwapRouter public uniV3Router;

    //univ3
    IUniswapV3Factory factoryV3=IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    ISwapRouter routerV3 = ISwapRouter(uniV3Router);
    

    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;


    constructor (address _router1,address _router2,address _factory1,address _factory2){
        _ThisOwner=msg.sender;
        changeArbitrageFactory(_factory1,_factory2);
        changeArbitrageRouter(_router1,_router2,0xE592427A0AEce92De3Edee1F18E0157C05861564);
    }

    modifier onlyOwner(){
        require(msg.sender==_ThisOwner,"Not owner");
        _;
    }

    event tradeMes(address sender,uint amount,uint outAmount,uint sqrt);

    //改变套利factory
    function changeArbitrageFactory(address _factory1,address _factory2)public onlyOwner{
        factory1=IUniswapV2Factory(_factory1);
        factory2=IUniswapV2Factory(_factory2);
    }

    //改变套利router
    function changeArbitrageRouter(address _router1,address _router2,address _uniV3Router)public onlyOwner{
        router1=IUniswapV2Router02(_router1);
        router2=IUniswapV2Router02(_router2);
        uniV3Router=ISwapRouter(_uniV3Router);
    }

    //套利策略1（传入使用了uni v2代码的router，第一个传入要交换的token最优路由，第二个传入套利的最优路由）
    //第三个传入from token，第四个传入第一次交换的目标token，第五个为输入token数量，第六个为滑点设置
    function dexV2Arbitrage(address bestInRouter,address bestOutRouter,address token0,address token1,uint inputAmount,uint spot)external{
        uint getReceiver1;
        uint getReceiver2;
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        //获取设置最小输出，滑点范围为(0.1%~1000)
        uint minOutAmount1=IUniswapV2Router02(bestInRouter).getAmountsOut(inputAmount,path)[1];
        uint amountOutMin1=minOutAmount1 * spot / 1000;
        //授权router
        require(IERC20(token0).approve(bestInRouter, inputAmount),"failed approve1");
        if(getContractBalance(token0,inputAmount)){

        }else{
            //转移到该合约
            TransferHelper.safeTransferFrom(token0,msg.sender,address(this),inputAmount);
            // IERC20(token0).transferFrom(msg.sender,address(this),inputAmount);
        }
        getReceiver1 = IUniswapV2Router02(bestInRouter).swapExactTokensForTokens(
            inputAmount,
            amountOutMin1,
            path,
            address(this),
            block.timestamp
        )[1];

        path[0] = address(token1);
        path[1] = address(token0);
        //最大输出与加入滑点的最小输出
        uint minOutAmount2=IUniswapV2Router02(bestOutRouter).getAmountsOut(getReceiver1,path)[1];
        uint amountOutMin2=minOutAmount2 * spot / 1000;
        //授权
        require(IERC20(token1).approve(bestOutRouter, getReceiver1),"failed approve2");
        getReceiver2 = IUniswapV2Router02(bestOutRouter).swapExactTokensForTokens(
            getReceiver1,
            amountOutMin2,
            path,
            address(this),
            block.timestamp
        )[1];
    }

    //套利策略2
    //univ3>=v2套利交换(第一个传入from token，第二个传入第一次交换后的目标token,第三个传入输入数量，第四个传入univ3费率(这里是3000))
    function uniV3ToV2Arbitrage(address token0,address token1,address bestOutRouter,uint128 inputAmount,uint24 _fee,uint spot)external {
        //先执行uni v3交换
        //授权路由，转移相应token到该合约进行交换
        if(getContractBalance(token0,inputAmount)){

        }else{
            TransferHelper.safeTransferFrom(token0,msg.sender,address(this),inputAmount);
        }
        TransferHelper.safeApprove(token0, address(uniV3Router), inputAmount);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: token0,
                tokenOut: token1,
                fee: _fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: inputAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        //通过uni的v3将token0转换成token1的数量
        uint receiveAmount1 = uniV3Router.exactInputSingle(params);

        //寻找到最优的套利路由后，执行套利
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token0);
        //获取设置最小输出，滑点范围为(0.1%~1000)
        uint minOutAmount2=IUniswapV2Router02(bestOutRouter).getAmountsOut(receiveAmount1,path)[1];
        uint amountOutMin2=minOutAmount2 * spot / 1000;

        //univ3输出tolen授权输出的最好router
        require(IERC20(token1).approve(bestOutRouter, receiveAmount1),"failed approve outRouter");
        uint receiveAmount2 = IUniswapV2Router02(bestOutRouter).swapExactTokensForTokens(
            receiveAmount1,
            amountOutMin2,
            path,
            address(this),
            block.timestamp
        )[1];
        emit tradeMes(msg.sender,receiveAmount1,receiveAmount2,amountOutMin2);
    }

    //套利策略3
    //v2=>univ3套利交换
    function v2ToUniV3Arbitrage(address token0,address token1,address bestInRouter,uint128 inputAmount,uint24 _fee,uint spot)external{
        //寻找到最优的套利路由后，执行套利
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        //获取设置最小输出，滑点范围为(0.1%~1000)
        uint minOutAmount1=IUniswapV2Router02(bestInRouter).getAmountsOut(inputAmount,path)[1];
        uint amountOutMin1=minOutAmount1 * spot / 1000;
        //授权router
        require(IERC20(token0).approve(bestInRouter, inputAmount),"failed approve1");
        //转移到该合约
        if(getContractBalance(token0,inputAmount)){

        }else{
            //转移到该合约
            TransferHelper.safeTransferFrom(token0,msg.sender,address(this),inputAmount);
        }
        uint receiveAmount1 = IUniswapV2Router02(bestInRouter).swapExactTokensForTokens(
            inputAmount,
            amountOutMin1,
            path,
            address(this),
            block.timestamp
        )[1];

        //授权univ3
        TransferHelper.safeApprove(token1, address(uniV3Router), receiveAmount1);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: token1,
                tokenOut: token0,
                fee: _fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: receiveAmount1,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        //通过uni的v3将token0转换成token1的数量
        uint receiveAmount2 = uniV3Router.exactInputSingle(params);
        emit tradeMes(msg.sender,receiveAmount1,receiveAmount2,0);
    }

    //执行uni v3的交换
    function doV3Swap(address token0,address token1,uint128 inputAmount,uint24 _fee)external returns(uint256 receiveAmount){
        //根据输入获得的最小输出值
        address thisPool=getPoolAddress(token0,token1,_fee);
        uint outMinAmount=getV3Data(thisPool,inputAmount);
        //转移相应token到该合约进行交换
        TransferHelper.safeTransferFrom(token0,msg.sender,address(this),inputAmount);
        TransferHelper.safeApprove(token0, address(uniV3Router), inputAmount);
        (uint160 _sqrtPriceX96,,,,,,) = IUniswapV3Pool(thisPool).slot0();
        //进行交换

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: token0,
                tokenOut: token1,
                fee: _fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: inputAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        //通过uni的v3将token0转换成token1的数量
        receiveAmount = uniV3Router.exactInputSingle(params);

        emit tradeMes(msg.sender,outMinAmount,receiveAmount,_sqrtPriceX96);
    }


    //套利 v2交换（原）
    // function doSushiV2Swap(address token0,address token1,uint inputAmount,uint spot)external {
    //     uint getReceiver1;
    //     uint getReceiver2;
    //     address[] memory path = new address[](2);
    //     path[0] = address(token0);
    //     path[1] = address(token1);
    //     //获取设置最小输出，滑点范围为(0.1%~1000)
    //     uint minOutAmount1=router2.getAmountsOut(inputAmount,path)[1];
    //     uint amountOutMin1=minOutAmount1 * spot / 1000;
    //     //授权router
    //     require(IERC20(token0).approve(address(router2), inputAmount),"failed approve1");
    //     //转移到该合约
    //     IERC20(token0).transferFrom(msg.sender,address(this),inputAmount);
    //     getReceiver1 = router2.swapExactTokensForTokens(
    //         inputAmount,
    //         amountOutMin1,
    //         path,
    //         address(this),
    //         block.timestamp
    //     )[1];

    //     path[0] = address(token1);
    //     path[1] = address(token0);
    //     uint minOutAmount2=router1.getAmountsOut(getReceiver1,path)[1];
    //     uint amountOutMin2=minOutAmount2 * spot / 1000;
    //     require(IERC20(token1).approve(address(router1), getReceiver1),"failed approve2");
    //     getReceiver2 = router1.swapExactTokensForTokens(
    //         getReceiver1,
    //         amountOutMin2,
    //         path,
    //         address(this),
    //         block.timestamp
    //     )[1];
    // }

    //得到v2pair地址
    function getPairAddress(address _factory,address token0,address token1)external view returns(address){
        return IUniswapV2Factory(_factory).getPair(token0,token1);
    }

    //提取token
    function withdrawBalance(address token,uint256 amount) external onlyOwner {
        require(amount > 0, "amount==0");
        if(token==address(0x0)){
            msg.sender.transfer(amount);
        }else{
            IERC20(token).transfer(msg.sender, amount);
        }
    }

    //得到最好的路由
    function getBestRouter(address token0,address token1,uint inputAmount)public view returns(uint,address){
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        uint a=router1.getAmountsOut(inputAmount,path)[1];
        uint b=router2.getAmountsOut(inputAmount,path)[1];
        return a>b?(a,address(router1)):(b,address(router2));
    }

    //获取到sushiswapv2的交易对数据(其余也是一样的读取方法
    function getRouterPairPrice(address router,address token0,address token1,uint inputAmount)public view returns(uint[] memory){
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);
        return IUniswapV2Router02(router).getAmountsOut(inputAmount,path);
    }

    //根据token0,token1获取到V3池子地址
    function getPoolAddress(address token0,address token1,uint24 _fee)public view returns(address thisPool){
        thisPool= factoryV3.getPool(
            token0,
            token1,
            _fee
        );
        return thisPool;
    }

    //获取到uni v3的交易对数据
    function getV3Data(address _v3Pool,uint128 inputAmount)public view returns(uint256){
        IUniswapV3Pool v3Pool = IUniswapV3Pool(_v3Pool);
        address token0 = v3Pool.token0();
        address token1 = v3Pool.token1();
        (,int24 tick,,,,,) = v3Pool.slot0();
        uint uniV3Amount=OracleLibrary.getQuoteAtTick(
            tick,
            inputAmount,
            token0,
            token1
        );
        return uniV3Amount;
    }

    //得到当前合约是否以及有足够的token数量
    function getContractBalance(address thisToken,uint amount)internal view returns(bool balanceState){
        uint thisTokenBalance=IERC20(thisToken).balanceOf(address(this));
        return thisTokenBalance>=amount?true:false;
    }

}

