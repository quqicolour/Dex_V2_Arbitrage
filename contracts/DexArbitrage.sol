//SPDX-License-Identifier:MIT
pragma solidity ^0.7.6;

import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";
import {UniswapV2Library} from "../libraries/UniswapV2Library.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import "hardhat/console.sol";
/*

* matic:0x02E1A80D80c3F1DE3492C14ce391ba94823E39F8
* usdt:0x2F6Ec96e6c64a910f5199CDF7Ad9a8456b254f99

 sushiRouter:0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506
 quickRouter:0x8954AfA98594b838bda56FE4C12a09D7739D179b

 sushiFactory:0xc35DADB65012eC5796536bD9864eD8773aBc74C4
 quickFactory:0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32

 quick pair:0x4A56a1213b8442d147Fe55cE4AfD3DB6612156E0
 sushi pair:0x2f458C0e872Bcc2f15AB96b0214D139b608ef050

 时间戳:>1994914681
*/

contract DexArbitrage{
    address private _ThisOwner;

    IUniswapV2Factory factory1;
    IUniswapV2Factory factory2;
    IUniswapV2Factory factory3;

    IUniswapV2Router02 router1;
    IUniswapV2Router02 router2;
    IUniswapV2Router02 router3;

    constructor (address _router1,address _router2,address _factory1,address _factory2){
        _ThisOwner=msg.sender;
        changeArbitrageFactory(_factory1,_factory2);
        changeArbitrageRouter(_router1,_router2);
    }

    modifier onlyOwner(){
        require(msg.sender==_ThisOwner,"Not owner");
        _;
    }

    mapping(uint=>uint[])public tradeMes;

    //套利策略1
    function dexV2Arbitrage(address token1,address token2,uint inputAmount,uint spot)external{
        uint getReceiver1;
        uint getReceiver2;
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);
        //获取设置最小输出，滑点范围为(0.1%~1000)
        uint amountOutMin1=inputAmount * spot / 1000;
        //授权router
        require(IERC20(token1).approve(address(router1), inputAmount),"failed approve1");
        //输入token数量需要>=最小输出(一般都是>最小输出)
        require(inputAmount>=amountOutMin1,"Amount1 errorr");
        //转移到该合约
        IERC20(token1).transferFrom(msg.sender,address(this),inputAmount);
        getReceiver1 = router1.swapExactTokensForTokens(
            inputAmount,
            amountOutMin1,
            path,
            address(this),
            block.timestamp
        )[1];

        path[0] = address(token2);
        path[1] = address(token1);
        
        require(IERC20(token2).approve(address(router2), getReceiver1),"failed approve2");
        getReceiver2 = router2.swapExactTokensForTokens(
            getReceiver1,
            0,
            path,
            address(this),
            block.timestamp
        )[1];
        console.log("getReceiver2:",getReceiver2);
    }

    //改变套利factory
    function changeArbitrageFactory(address _factory1,address _factory2)public onlyOwner{
        factory1=IUniswapV2Factory(_factory1);
        factory2=IUniswapV2Factory(_factory2);
    }

    //改变套利router
    function changeArbitrageRouter(address _router1,address _router2)public onlyOwner{
        router1=IUniswapV2Router02(_router1);
        router2=IUniswapV2Router02(_router2);
    }

    //执行sushiSwap v2交换
    function doSushiV2Swap(address token1,address token2,uint inputAmount,uint spot)external {
        uint[] memory allAmounts1;
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);
        //获取设置最小输出，滑点范围为(0.1%~1000)
        uint amountOutMin1=inputAmount * spot / 1000;
        //授权router
        require(IERC20(token1).approve(address(router1), inputAmount),"failed approve");
        //输入token数量需要>=最小输出(一般都是>最小输出)
        require(inputAmount>=amountOutMin1,"Amount errorr");
        //转移到该合约
        IERC20(token1).transferFrom(msg.sender,address(this),inputAmount);
        allAmounts1 = router1.swapExactTokensForTokens(
            inputAmount,
            amountOutMin1,
            path,
            address(this),
            block.timestamp
        );
        tradeMes[0]=allAmounts1;
    }

    //获取到sushiswapv2的交易对数据
    function getSushiPairPrice1(address token1,address token2,uint inputAmount)public view returns(uint[] memory){
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);
        return router1.getAmountsOut(inputAmount,path);
    }

    //获取到quickswapv2的交易对数据
    function getQuickPairPrice2(address token1,address token2,uint inputAmount)public view returns(uint[] memory){
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);
        return router2.getAmountsOut(inputAmount,path);
    }

    //获取到balance的交易对数据
    function getSushiPairPrice3(address token1,address token2,uint inputAmount)public view returns(uint[] memory){
        address[] memory path = new address[](2);
        path[0] = address(token1);
        path[1] = address(token2);
        return router3.getAmountsOut(inputAmount,path);
    }

    //获取到uni v3的交易对数据
    

}
