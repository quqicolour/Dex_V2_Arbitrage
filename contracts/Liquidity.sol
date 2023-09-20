//SPDX-License-Identifier:MIT
pragma solidity >=0.7.6;
pragma abicoder v2;

import {SafeMath} from "../libraries/SafeMath.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";
import { IERC20 } from "../interfaces/IERC20.sol";

//uni v3
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";
import {IPoolInitializer} from "../interfaces/IPoolInitializer.sol";

contract LiqulityManage{
    /*
        *ganache:
        *pair:0xe3bd75dECb83cCb0FD7CFc41A97557065eA7680D
    */

    IUniswapV3Factory factoryV3=IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    INonfungiblePositionManager nonfungiblePositionManager=INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    //添加V2流动性
    function addV2Liquidity( 
        address v2Router,
        address token0,
        address token1,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadLine
    )external{
        IERC20(token0).approve(address(v2Router), amountADesired);
        IERC20(token1).approve(address(v2Router), amountBDesired);
        IERC20(token0).transferFrom(msg.sender,address(this),amountADesired);
        IERC20(token1).transferFrom(msg.sender,address(this),amountBDesired);
        IUniswapV2Router02(v2Router).addLiquidity(
            token0,
            token1,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            to,
            deadLine
        );
    }

    //添加v3流动性
    function addV3Liquidity(
        address _token0,
        address _token1,
        uint24 _fee,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _amount0Desired,
        uint256 _amount1Desired,
        address _recipient
    ) external returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
    ){  
        INonfungiblePositionManager.MintParams  memory newMintParams = 
        INonfungiblePositionManager.MintParams({
            token0:_token0,
            token1:_token1,
            fee:_fee,
            tickLower:_tickLower,
            tickUpper:_tickUpper,
            amount0Desired:_amount0Desired,
            amount1Desired:_amount1Desired,
            amount0Min:1000,
            amount1Min:1000,
            recipient:_recipient,
            deadline:block.timestamp
        });
        (uint256 _tokenId,,,)=nonfungiblePositionManager.mint(newMintParams);

        IERC20(_token0).approve(address(nonfungiblePositionManager), _amount0Desired);
        IERC20(_token1).approve(address(nonfungiblePositionManager), _amount1Desired);
        IERC20(_token0).transferFrom(msg.sender,address(this),_amount0Desired);
        IERC20(_token1).transferFrom(msg.sender,address(this),_amount1Desired);
        INonfungiblePositionManager.IncreaseLiquidityParams memory params =
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: _tokenId,
                amount0Desired: _amount0Desired,
                amount1Desired: _amount1Desired,
                amount0Min: 1000,
                amount1Min: 1000,
                deadline: block.timestamp
            });

        (liquidity, amount0, amount1) = nonfungiblePositionManager.increaseLiquidity(params);
    }

    //创建v2池
    function createV2Pool(address _factory,address token0,address token1)external{
        IUniswapV2Factory(_factory).createPair(token0,token1);
    }

     //创建v3池
    function createV3Pool(address token0,address token1,uint24 _fee)external returns (address _pool){
        _pool = factoryV3.createPool(
            token0,
            token1,
            _fee
        );
        return _pool;
    }

    //根据token0,token1获取到V3池子地址(第一种方法)
    function getV3PoolAddress(address token0,address token1,uint24 _fee)public view returns(address){
        address thisPool= PoolAddress.computeAddress(
            address(factoryV3),
            PoolAddress.getPoolKey(
            token0,
            token1,
            _fee
            )
        );
        return thisPool;
    }

    //根据token0,token1获取到V3池子地址(第二种方法)
    function getPoolAddress(address token0,address token1,uint24 _fee)public view returns(address thisPool){
        thisPool= factoryV3.getPool(
            token0,
            token1,
            _fee
        );
        return thisPool;
    }

}
