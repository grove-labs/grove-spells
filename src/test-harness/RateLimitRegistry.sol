// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Ethereum }  from "lib/grove-address-registry/src/Ethereum.sol";
import { Avalanche } from "lib/grove-address-registry/src/Avalanche.sol";
import { Base }      from "lib/grove-address-registry/src/Base.sol";
import { Plume }     from "lib/grove-address-registry/src/Plume.sol";
import { Robinhood } from "lib/grove-address-registry/src/Robinhood.sol";

import { ChainId, ChainIdUtils } from "src/libraries/helpers/ChainId.sol";

import { Category, CommonRateLimitTests, RateLimitIntegration } from "./CommonRateLimitTests.sol";

/// @dev Every rate limit key Grove has onboarded, mapped back to the integration it
/// governs. Keys are hashes and cannot be reversed, so this mapping is maintained by hand
/// and kept honest by the coverage assertion: a key that is live on chain but missing here
/// fails the suite.
abstract contract RateLimitRegistry is CommonRateLimitTests {

    function _almIntegrations() internal view override returns (RateLimitIntegration[] memory) {
        ChainId chain = ChainIdUtils.fromUint(block.chainid);

        if (chain == ChainIdUtils.Ethereum())  return _almIntegrationsEthereum();
        if (chain == ChainIdUtils.Avalanche()) return _almIntegrationsAvalanche();
        if (chain == ChainIdUtils.Base())      return _almIntegrationsBase();
        if (chain == ChainIdUtils.Plume())     return _almIntegrationsPlume();
        if (chain == ChainIdUtils.Robinhood()) return _almIntegrationsRobinhood();

        revert("RateLimitRegistry/no-alm-integrations-for-chain");
    }

    function _pauIntegrations() internal view override returns (RateLimitIntegration[] memory) {
        require(
            ChainIdUtils.fromUint(block.chainid) == ChainIdUtils.Ethereum(),
            "RateLimitRegistry/no-pau-integrations-for-chain"
        );

        return _pauIntegrationsEthereum();
    }

    function _almIntegrationsEthereum() internal pure returns (RateLimitIntegration[] memory ints) {
        ints = new RateLimitIntegration[](45);

        ints[0] = RateLimitIntegration({
            label       : "Core",
            category    : Category.CORE,
            integration : address(0),
            asset       : Ethereum.USDS,
            entryId     : _limitKey("LIMIT_USDS_MINT"),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[1] = RateLimitIntegration({
            label       : "PSM",
            category    : Category.PSM,
            integration : address(0),
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_USDS_TO_USDC"),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[2] = RateLimitIntegration({
            label       : "Transfer-USDC-BUIDLI_DEPOSIT",
            category    : Category.TRANSFER_ASSET,
            integration : Ethereum.BUIDLI_DEPOSIT,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Ethereum.USDC, Ethereum.BUIDLI_DEPOSIT),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[3] = RateLimitIntegration({
            label       : "Transfer-BUIDLI-BUIDLI_REDEEM",
            category    : Category.TRANSFER_ASSET,
            integration : Ethereum.BUIDLI_REDEEM,
            asset       : Ethereum.BUIDLI,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Ethereum.BUIDLI, Ethereum.BUIDLI_REDEEM),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[4] = RateLimitIntegration({
            label       : "CCTP",
            category    : Category.CCTP,
            integration : address(0),
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_USDC_TO_CCTP"),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[5] = RateLimitIntegration({
            label       : "CCTP-1",
            category    : Category.CCTP,
            integration : address(0),
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_USDC_TO_DOMAIN", 1),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[6] = RateLimitIntegration({
            label       : "Ethena",
            category    : Category.ETHENA,
            integration : address(0),
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_USDE_MINT"),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[7] = RateLimitIntegration({
            label       : "Ethena",
            category    : Category.ETHENA,
            integration : address(0),
            asset       : Ethereum.USDE,
            entryId     : bytes32(0),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_USDE_BURN"),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[8] = RateLimitIntegration({
            label       : "ERC4626-SUSDE",
            category    : Category.ERC4626,
            integration : Ethereum.SUSDE,
            asset       : Ethereum.USDE,
            entryId     : _limitKey("LIMIT_4626_DEPOSIT", Ethereum.SUSDE),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[9] = RateLimitIntegration({
            label       : "Ethena",
            category    : Category.ETHENA,
            integration : address(0),
            asset       : Ethereum.SUSDE,
            entryId     : bytes32(0),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_SUSDE_COOLDOWN"),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[10] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_JAAA_USDC",
            category    : Category.CENTRIFUGE,
            integration : Ethereum.CENTRIFUGE_JAAA_USDC,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_7540_DEPOSIT", Ethereum.CENTRIFUGE_JAAA_USDC),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_7540_REDEEM", Ethereum.CENTRIFUGE_JAAA_USDC),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[11] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_JTRSY_USDC",
            category    : Category.CENTRIFUGE,
            integration : Ethereum.CENTRIFUGE_JTRSY_USDC,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_7540_DEPOSIT", Ethereum.CENTRIFUGE_JTRSY_USDC),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_7540_REDEEM", Ethereum.CENTRIFUGE_JTRSY_USDC),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[12] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_JAAA_USDC-5",
            category    : Category.CENTRIFUGE,
            integration : Ethereum.CENTRIFUGE_JAAA_USDC,
            asset       : 0x5a0F93D040De44e78F251b03c43be9CF317Dcf64,
            entryId     : _limitKey("LIMIT_CENTRIFUGE_TRANSFER", Ethereum.CENTRIFUGE_JAAA_USDC, 5),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[13] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_JTRSY_USDC-5",
            category    : Category.CENTRIFUGE,
            integration : Ethereum.CENTRIFUGE_JTRSY_USDC,
            asset       : 0x8c213ee79581Ff4984583C6a801e5263418C4b86,
            entryId     : _limitKey("LIMIT_CENTRIFUGE_TRANSFER", Ethereum.CENTRIFUGE_JTRSY_USDC, 5),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[14] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_JTRSY_USDC-4",
            category    : Category.CENTRIFUGE,
            integration : Ethereum.CENTRIFUGE_JTRSY_USDC,
            asset       : 0x8c213ee79581Ff4984583C6a801e5263418C4b86,
            entryId     : _limitKey("LIMIT_CENTRIFUGE_TRANSFER", Ethereum.CENTRIFUGE_JTRSY_USDC, 4),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[15] = RateLimitIntegration({
            label       : "Transfer-USDC-FALCON_X_DEPOSIT",
            category    : Category.TRANSFER_ASSET,
            integration : Ethereum.FALCON_X_DEPOSIT,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Ethereum.USDC, Ethereum.FALCON_X_DEPOSIT),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[16] = RateLimitIntegration({
            label       : "Curve-CURVE_RLUSD_USDC",
            category    : Category.CURVE_LP,
            integration : Ethereum.CURVE_RLUSD_USDC,
            asset       : address(0),
            entryId     : bytes32(0),
            entryId2    : _limitKey("LIMIT_CURVE_SWAP", Ethereum.CURVE_RLUSD_USDC),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[17] = RateLimitIntegration({
            label       : "Aave-AAVE_CORE_USDC",
            category    : Category.AAVE,
            integration : Ethereum.AAVE_CORE_USDC,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_AAVE_DEPOSIT", Ethereum.AAVE_CORE_USDC),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_AAVE_WITHDRAW", Ethereum.AAVE_CORE_USDC),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[18] = RateLimitIntegration({
            label       : "Aave-AAVE_CORE_RLUSD",
            category    : Category.AAVE,
            integration : Ethereum.AAVE_CORE_RLUSD,
            asset       : Ethereum.RLUSD,
            entryId     : _limitKey("LIMIT_AAVE_DEPOSIT", Ethereum.AAVE_CORE_RLUSD),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_AAVE_WITHDRAW", Ethereum.AAVE_CORE_RLUSD),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[19] = RateLimitIntegration({
            label       : "Aave-AAVE_HORIZON_USDC",
            category    : Category.AAVE,
            integration : Ethereum.AAVE_HORIZON_USDC,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_AAVE_DEPOSIT", Ethereum.AAVE_HORIZON_USDC),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_AAVE_WITHDRAW", Ethereum.AAVE_HORIZON_USDC),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[20] = RateLimitIntegration({
            label       : "Aave-AAVE_HORIZON_RLUSD",
            category    : Category.AAVE,
            integration : Ethereum.AAVE_HORIZON_RLUSD,
            asset       : Ethereum.RLUSD,
            entryId     : _limitKey("LIMIT_AAVE_DEPOSIT", Ethereum.AAVE_HORIZON_RLUSD),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_AAVE_WITHDRAW", Ethereum.AAVE_HORIZON_RLUSD),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[21] = RateLimitIntegration({
            label       : "Transfer-USDC-STAC_DEPOSIT",
            category    : Category.TRANSFER_ASSET,
            integration : Ethereum.STAC_DEPOSIT,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Ethereum.USDC, Ethereum.STAC_DEPOSIT),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[22] = RateLimitIntegration({
            label       : "Transfer-STAC-STAC_REDEEM",
            category    : Category.TRANSFER_ASSET,
            integration : Ethereum.STAC_REDEEM,
            asset       : Ethereum.STAC,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Ethereum.STAC, Ethereum.STAC_REDEEM),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[23] = RateLimitIntegration({
            label       : "Transfer-USDC-GALAXY_ARCH_CLO_DEPOSIT",
            category    : Category.TRANSFER_ASSET,
            integration : Ethereum.GALAXY_ARCH_CLO_DEPOSIT,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Ethereum.USDC, Ethereum.GALAXY_ARCH_CLO_DEPOSIT),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[24] = RateLimitIntegration({
            label       : "ERC4626-GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT",
            category    : Category.ERC4626,
            integration : Ethereum.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_4626_DEPOSIT", Ethereum.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_4626_WITHDRAW", Ethereum.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[25] = RateLimitIntegration({
            label       : "Transfer-USDC-RLUSD_MINT_BURN",
            category    : Category.TRANSFER_ASSET,
            integration : Ethereum.RLUSD_MINT_BURN,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Ethereum.USDC, Ethereum.RLUSD_MINT_BURN),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[26] = RateLimitIntegration({
            label       : "Transfer-RLUSD-RLUSD_MINT_BURN",
            category    : Category.TRANSFER_ASSET,
            integration : Ethereum.RLUSD_MINT_BURN,
            asset       : Ethereum.RLUSD,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Ethereum.RLUSD, Ethereum.RLUSD_MINT_BURN),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[27] = RateLimitIntegration({
            label       : "CCTP-6",
            category    : Category.CCTP,
            integration : address(0),
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_USDC_TO_DOMAIN", 6),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[28] = RateLimitIntegration({
            label       : "Transfer-USDC-AGORA_AUSD_MINT",
            category    : Category.TRANSFER_ASSET,
            integration : Ethereum.AGORA_AUSD_MINT,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Ethereum.USDC, Ethereum.AGORA_AUSD_MINT),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[29] = RateLimitIntegration({
            label       : "Transfer-AUSD-AGORA_AUSD_REDEEM",
            category    : Category.TRANSFER_ASSET,
            integration : Ethereum.AGORA_AUSD_REDEEM,
            asset       : Ethereum.AUSD,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Ethereum.AUSD, Ethereum.AGORA_AUSD_REDEEM),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[30] = RateLimitIntegration({
            label       : "Curve-CURVE_AUSD_USDC",
            category    : Category.CURVE_LP,
            integration : Ethereum.CURVE_AUSD_USDC,
            asset       : address(0),
            entryId     : _limitKey("LIMIT_CURVE_DEPOSIT", Ethereum.CURVE_AUSD_USDC),
            entryId2    : _limitKey("LIMIT_CURVE_SWAP", Ethereum.CURVE_AUSD_USDC),
            exitId      : _limitKey("LIMIT_CURVE_WITHDRAW", Ethereum.CURVE_AUSD_USDC),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[31] = RateLimitIntegration({
            label       : "UniswapV3-AUSD-UNISWAP_V3_AUSD_USDC",
            category    : Category.UNISWAP_V3,
            integration : Ethereum.UNISWAP_V3_AUSD_USDC,
            asset       : Ethereum.AUSD,
            entryId     : _limitKey("LIMIT_UNISWAP_V3_DEPOSIT", Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC),
            entryId2    : _limitKey("LIMIT_UNISWAP_V3_SWAP", Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC),
            exitId      : _limitKey("LIMIT_UNISWAP_V3_WITHDRAW", Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[32] = RateLimitIntegration({
            label       : "UniswapV3-USDC-UNISWAP_V3_AUSD_USDC",
            category    : Category.UNISWAP_V3,
            integration : Ethereum.UNISWAP_V3_AUSD_USDC,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_UNISWAP_V3_DEPOSIT", Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC),
            entryId2    : _limitKey("LIMIT_UNISWAP_V3_SWAP", Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC),
            exitId      : _limitKey("LIMIT_UNISWAP_V3_WITHDRAW", Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[33] = RateLimitIntegration({
            label       : "Curve-CURVE_PYUSD_USDS",
            category    : Category.CURVE_LP,
            integration : Ethereum.CURVE_PYUSD_USDS,
            asset       : address(0),
            entryId     : bytes32(0),
            entryId2    : _limitKey("LIMIT_CURVE_SWAP", Ethereum.CURVE_PYUSD_USDS),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[34] = RateLimitIntegration({
            label       : "ERC4626-GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT",
            category    : Category.ERC4626,
            integration : Ethereum.GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_4626_DEPOSIT", Ethereum.GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_4626_WITHDRAW", Ethereum.GROVE_X_STEAKHOUSE_USDC_HY_V2_MORPHO_VAULT),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[35] = RateLimitIntegration({
            label       : "ERC4626-STEAKHOUSE_PYUSD_MORPHO_VAULT",
            category    : Category.ERC4626,
            integration : Ethereum.STEAKHOUSE_PYUSD_MORPHO_VAULT,
            asset       : Ethereum.PYUSD,
            entryId     : _limitKey("LIMIT_4626_DEPOSIT", Ethereum.STEAKHOUSE_PYUSD_MORPHO_VAULT),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_4626_WITHDRAW", Ethereum.STEAKHOUSE_PYUSD_MORPHO_VAULT),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[36] = RateLimitIntegration({
            label       : "ERC4626-GROVE_X_STEAKHOUSE_AUSD_V2_MORPHO_VAULT",
            category    : Category.ERC4626,
            integration : Ethereum.GROVE_X_STEAKHOUSE_AUSD_V2_MORPHO_VAULT,
            asset       : Ethereum.AUSD,
            entryId     : _limitKey("LIMIT_4626_DEPOSIT", Ethereum.GROVE_X_STEAKHOUSE_AUSD_V2_MORPHO_VAULT),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_4626_WITHDRAW", Ethereum.GROVE_X_STEAKHOUSE_AUSD_V2_MORPHO_VAULT),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[37] = RateLimitIntegration({
            label       : "Transfer-USDC-GALAXY_WAREHOUSE_DEPOSIT",
            category    : Category.TRANSFER_ASSET,
            integration : Ethereum.GALAXY_WAREHOUSE_DEPOSIT,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Ethereum.USDC, Ethereum.GALAXY_WAREHOUSE_DEPOSIT),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[38] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_ACRDX_USDC",
            category    : Category.CENTRIFUGE,
            integration : Ethereum.CENTRIFUGE_ACRDX_USDC,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_7540_DEPOSIT", Ethereum.CENTRIFUGE_ACRDX_USDC),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_7540_REDEEM", Ethereum.CENTRIFUGE_ACRDX_USDC),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[39] = RateLimitIntegration({
            label       : "ERC4626-SENTORA_PYUSD_MAIN_V2_MORPHO_VAULT",
            category    : Category.ERC4626,
            integration : Ethereum.SENTORA_PYUSD_MAIN_V2_MORPHO_VAULT,
            asset       : Ethereum.PYUSD,
            entryId     : _limitKey("LIMIT_4626_DEPOSIT", Ethereum.SENTORA_PYUSD_MAIN_V2_MORPHO_VAULT),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_4626_WITHDRAW", Ethereum.SENTORA_PYUSD_MAIN_V2_MORPHO_VAULT),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[40] = RateLimitIntegration({
            label       : "ERC4626-SENTORA_RLUSD_MAIN_V2_MORPHO_VAULT",
            category    : Category.ERC4626,
            integration : Ethereum.SENTORA_RLUSD_MAIN_V2_MORPHO_VAULT,
            asset       : Ethereum.RLUSD,
            entryId     : _limitKey("LIMIT_4626_DEPOSIT", Ethereum.SENTORA_RLUSD_MAIN_V2_MORPHO_VAULT),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_4626_WITHDRAW", Ethereum.SENTORA_RLUSD_MAIN_V2_MORPHO_VAULT),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[41] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_JTRSY_USDS",
            category    : Category.CENTRIFUGE,
            integration : Ethereum.CENTRIFUGE_JTRSY_USDS,
            asset       : Ethereum.USDS,
            entryId     : _limitKey("LIMIT_7540_DEPOSIT", Ethereum.CENTRIFUGE_JTRSY_USDS),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_7540_REDEEM", Ethereum.CENTRIFUGE_JTRSY_USDS),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[42] = RateLimitIntegration({
            label       : "LayerZero-USDS_SKYLINK_OFT-30106",
            category    : Category.LAYERZERO,
            integration : Ethereum.USDS_SKYLINK_OFT,
            asset       : Ethereum.USDS,
            entryId     : _limitKey("LIMIT_LAYERZERO_TRANSFER", Ethereum.USDS_SKYLINK_OFT, 30106),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[43] = RateLimitIntegration({
            label       : "ERC4626-GROVE_X_STEAKHOUSE_RLUSD_V2_MORPHO_VAULT",
            category    : Category.ERC4626,
            integration : Ethereum.GROVE_X_STEAKHOUSE_RLUSD_V2_MORPHO_VAULT,
            asset       : Ethereum.RLUSD,
            entryId     : _limitKey("LIMIT_4626_DEPOSIT", Ethereum.GROVE_X_STEAKHOUSE_RLUSD_V2_MORPHO_VAULT),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_4626_WITHDRAW", Ethereum.GROVE_X_STEAKHOUSE_RLUSD_V2_MORPHO_VAULT),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[44] = RateLimitIntegration({
            label       : "Transfer-USDC-PAXOS_USDC_DEPOSIT_WALLET",
            category    : Category.TRANSFER_ASSET,
            integration : Ethereum.PAXOS_USDC_DEPOSIT_WALLET,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Ethereum.USDC, Ethereum.PAXOS_USDC_DEPOSIT_WALLET),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

    }

    function _pauIntegrationsEthereum() internal pure returns (RateLimitIntegration[] memory ints) {
        ints = new RateLimitIntegration[](9);

        ints[0] = RateLimitIntegration({
            label       : "Core",
            category    : Category.CORE,
            integration : address(0),
            asset       : Ethereum.USDS,
            entryId     : _limitKey("LIMIT_USDS_MINT"),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_USDS_BURN"),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[1] = RateLimitIntegration({
            label       : "PSM",
            category    : Category.PSM,
            integration : address(0),
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_USDS_TO_USDC"),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_USDC_TO_USDS"),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[2] = RateLimitIntegration({
            label       : "Basin-USDS-JTRSY_GROVE_BASIN",
            category    : Category.BASIN,
            integration : Ethereum.JTRSY_GROVE_BASIN,
            asset       : Ethereum.USDS,
            entryId     : _limitKey("LIMIT_BASIN_DEPOSIT", Ethereum.USDS, Ethereum.JTRSY_GROVE_BASIN),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_BASIN_WITHDRAW", Ethereum.USDS, Ethereum.JTRSY_GROVE_BASIN),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[3] = RateLimitIntegration({
            label       : "Basin-USDC-JTRSY_GROVE_BASIN",
            category    : Category.BASIN,
            integration : Ethereum.JTRSY_GROVE_BASIN,
            asset       : Ethereum.USDC,
            entryId     : bytes32(0),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_BASIN_WITHDRAW", Ethereum.USDC, Ethereum.JTRSY_GROVE_BASIN),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[4] = RateLimitIntegration({
            label       : "Basin-USDS-BUIDL_GROVE_BASIN",
            category    : Category.BASIN,
            integration : Ethereum.BUIDL_GROVE_BASIN,
            asset       : Ethereum.USDS,
            entryId     : _limitKey("LIMIT_BASIN_DEPOSIT", Ethereum.USDS, Ethereum.BUIDL_GROVE_BASIN),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_BASIN_WITHDRAW", Ethereum.USDS, Ethereum.BUIDL_GROVE_BASIN),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[5] = RateLimitIntegration({
            label       : "Basin-USDC-BUIDL_GROVE_BASIN",
            category    : Category.BASIN,
            integration : Ethereum.BUIDL_GROVE_BASIN,
            asset       : Ethereum.USDC,
            entryId     : bytes32(0),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_BASIN_WITHDRAW", Ethereum.USDC, Ethereum.BUIDL_GROVE_BASIN),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        // The PAU UniV3 module keys a pool-wide limit on the pool alone, in 18 decimals
        // across both tokens, next to the per-token limits the ALM controller also uses.
        // Swap has no pool-wide key.
        ints[6] = RateLimitIntegration({
            label       : "UniswapV3-UNISWAP_V3_AUSD_USDC",
            category    : Category.UNISWAP_V3,
            integration : Ethereum.UNISWAP_V3_AUSD_USDC,
            asset       : address(0),
            entryId     : _limitKey("LIMIT_UNISWAP_V3_DEPOSIT", Ethereum.UNISWAP_V3_AUSD_USDC),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_UNISWAP_V3_WITHDRAW", Ethereum.UNISWAP_V3_AUSD_USDC),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[7] = RateLimitIntegration({
            label       : "UniswapV3-AUSD-UNISWAP_V3_AUSD_USDC",
            category    : Category.UNISWAP_V3,
            integration : Ethereum.UNISWAP_V3_AUSD_USDC,
            asset       : Ethereum.AUSD,
            entryId     : _limitKey("LIMIT_UNISWAP_V3_DEPOSIT", Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC),
            entryId2    : _limitKey("LIMIT_UNISWAP_V3_SWAP", Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC),
            exitId      : _limitKey("LIMIT_UNISWAP_V3_WITHDRAW", Ethereum.AUSD, Ethereum.UNISWAP_V3_AUSD_USDC),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[8] = RateLimitIntegration({
            label       : "UniswapV3-USDC-UNISWAP_V3_AUSD_USDC",
            category    : Category.UNISWAP_V3,
            integration : Ethereum.UNISWAP_V3_AUSD_USDC,
            asset       : Ethereum.USDC,
            entryId     : _limitKey("LIMIT_UNISWAP_V3_DEPOSIT", Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC),
            entryId2    : _limitKey("LIMIT_UNISWAP_V3_SWAP", Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC),
            exitId      : _limitKey("LIMIT_UNISWAP_V3_WITHDRAW", Ethereum.USDC, Ethereum.UNISWAP_V3_AUSD_USDC),
            exitId2     : bytes32(0),
            extraData   : ""
        });

    }

    function _almIntegrationsAvalanche() internal pure returns (RateLimitIntegration[] memory ints) {
        ints = new RateLimitIntegration[](8);

        ints[0] = RateLimitIntegration({
            label       : "CCTP",
            category    : Category.CCTP,
            integration : address(0),
            asset       : Avalanche.USDC,
            entryId     : _limitKey("LIMIT_USDC_TO_CCTP"),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[1] = RateLimitIntegration({
            label       : "CCTP-0",
            category    : Category.CCTP,
            integration : address(0),
            asset       : Avalanche.USDC,
            entryId     : _limitKey("LIMIT_USDC_TO_DOMAIN", 0),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[2] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_JAAA",
            category    : Category.CENTRIFUGE,
            integration : Avalanche.CENTRIFUGE_JAAA,
            asset       : Avalanche.USDC,
            entryId     : _limitKey("LIMIT_7540_DEPOSIT", Avalanche.CENTRIFUGE_JAAA),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_7540_REDEEM", Avalanche.CENTRIFUGE_JAAA),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[3] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_JTRSY",
            category    : Category.CENTRIFUGE,
            integration : Avalanche.CENTRIFUGE_JTRSY,
            asset       : Avalanche.USDC,
            entryId     : _limitKey("LIMIT_7540_DEPOSIT", Avalanche.CENTRIFUGE_JTRSY),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_7540_REDEEM", Avalanche.CENTRIFUGE_JTRSY),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[4] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_JAAA-1",
            category    : Category.CENTRIFUGE,
            integration : Avalanche.CENTRIFUGE_JAAA,
            asset       : 0x58F93d6b1EF2F44eC379Cb975657C132CBeD3B6b,
            entryId     : _limitKey("LIMIT_CENTRIFUGE_TRANSFER", Avalanche.CENTRIFUGE_JAAA, 1),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[5] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_JTRSY-1",
            category    : Category.CENTRIFUGE,
            integration : Avalanche.CENTRIFUGE_JTRSY,
            asset       : 0xa5d465251fBCc907f5Dd6bB2145488DFC6a2627b,
            entryId     : _limitKey("LIMIT_CENTRIFUGE_TRANSFER", Avalanche.CENTRIFUGE_JTRSY, 1),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[6] = RateLimitIntegration({
            label       : "LayerZero-USDS_SKYLINK_OFT-30101",
            category    : Category.LAYERZERO,
            integration : Avalanche.USDS_SKYLINK_OFT,
            asset       : Avalanche.USDS,
            entryId     : _limitKey("LIMIT_LAYERZERO_TRANSFER", Avalanche.USDS_SKYLINK_OFT, 30101),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[7] = RateLimitIntegration({
            label       : "Curve-CURVE_USDS_USDC",
            category    : Category.CURVE_LP,
            integration : Avalanche.CURVE_USDS_USDC,
            asset       : address(0),
            entryId     : _limitKey("LIMIT_CURVE_DEPOSIT", Avalanche.CURVE_USDS_USDC),
            entryId2    : _limitKey("LIMIT_CURVE_SWAP", Avalanche.CURVE_USDS_USDC),
            exitId      : _limitKey("LIMIT_CURVE_WITHDRAW", Avalanche.CURVE_USDS_USDC),
            exitId2     : bytes32(0),
            extraData   : ""
        });

    }

    function _almIntegrationsBase() internal pure returns (RateLimitIntegration[] memory ints) {
        ints = new RateLimitIntegration[](4);

        ints[0] = RateLimitIntegration({
            label       : "ERC4626-GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT",
            category    : Category.ERC4626,
            integration : Base.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT,
            asset       : Base.USDC,
            entryId     : _limitKey("LIMIT_4626_DEPOSIT", Base.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_4626_WITHDRAW", Base.GROVE_X_STEAKHOUSE_USDC_MORPHO_VAULT),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[1] = RateLimitIntegration({
            label       : "CCTP-0",
            category    : Category.CCTP,
            integration : address(0),
            asset       : Base.USDC,
            entryId     : _limitKey("LIMIT_USDC_TO_DOMAIN", 0),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[2] = RateLimitIntegration({
            label       : "CCTP",
            category    : Category.CCTP,
            integration : address(0),
            asset       : Base.USDC,
            entryId     : _limitKey("LIMIT_USDC_TO_CCTP"),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[3] = RateLimitIntegration({
            label       : "ERC4626-STEAKHOUSE_PRIME_INSTANT_V2_MORPHO_VAULT",
            category    : Category.ERC4626,
            integration : Base.STEAKHOUSE_PRIME_INSTANT_V2_MORPHO_VAULT,
            asset       : Base.USDC,
            entryId     : _limitKey("LIMIT_4626_DEPOSIT", Base.STEAKHOUSE_PRIME_INSTANT_V2_MORPHO_VAULT),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_4626_WITHDRAW", Base.STEAKHOUSE_PRIME_INSTANT_V2_MORPHO_VAULT),
            exitId2     : bytes32(0),
            extraData   : ""
        });

    }

    function _almIntegrationsPlume() internal pure returns (RateLimitIntegration[] memory ints) {
        ints = new RateLimitIntegration[](2);

        ints[0] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_ACRDX",
            category    : Category.CENTRIFUGE,
            integration : Plume.CENTRIFUGE_ACRDX,
            asset       : Plume.USDC,
            entryId     : _limitKey("LIMIT_7540_DEPOSIT", Plume.CENTRIFUGE_ACRDX),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_7540_REDEEM", Plume.CENTRIFUGE_ACRDX),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[1] = RateLimitIntegration({
            label       : "Centrifuge-CENTRIFUGE_JTRSY",
            category    : Category.CENTRIFUGE,
            integration : Plume.CENTRIFUGE_JTRSY,
            asset       : Plume.USDC,
            entryId     : bytes32(0),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_7540_REDEEM", Plume.CENTRIFUGE_JTRSY),
            exitId2     : bytes32(0),
            extraData   : ""
        });

    }

    function _almIntegrationsRobinhood() internal pure returns (RateLimitIntegration[] memory ints) {
        ints = new RateLimitIntegration[](2);

        ints[0] = RateLimitIntegration({
            label       : "Transfer-USDG-PAXOS_USDG_DEPOSIT_WALLET",
            category    : Category.TRANSFER_ASSET,
            integration : Robinhood.PAXOS_USDG_DEPOSIT_WALLET,
            asset       : Robinhood.USDG,
            entryId     : _limitKey("LIMIT_ASSET_TRANSFER", Robinhood.USDG, Robinhood.PAXOS_USDG_DEPOSIT_WALLET),
            entryId2    : bytes32(0),
            exitId      : bytes32(0),
            exitId2     : bytes32(0),
            extraData   : ""
        });

        ints[1] = RateLimitIntegration({
            label       : "ERC4626-GROVE_X_STEAKHOUSE_USDG_VAULT",
            category    : Category.ERC4626,
            integration : Robinhood.GROVE_X_STEAKHOUSE_USDG_VAULT,
            asset       : Robinhood.USDG,
            entryId     : _limitKey("LIMIT_4626_DEPOSIT", Robinhood.GROVE_X_STEAKHOUSE_USDG_VAULT),
            entryId2    : bytes32(0),
            exitId      : _limitKey("LIMIT_4626_WITHDRAW", Robinhood.GROVE_X_STEAKHOUSE_USDG_VAULT),
            exitId2     : bytes32(0),
            extraData   : ""
        });

    }
}
