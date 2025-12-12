import { describe, expect, it, beforeEach } from "vitest";
import { Cl, ClarityType } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;
const wallet3 = accounts.get("wallet_3")!;
const oracle = accounts.get("wallet_4")!;

// Constants from contract
const MIN_STAKE = 1_000_000; // 1 STX
const MAX_STAKE = 100_000_000; // 100 STX
const PLATFORM_FEE_BPS = 300; // 3%

// Error codes
const ERR_NOT_AUTHORIZED = Cl.error(Cl.uint(100));
const ERR_MARKET_NOT_FOUND = Cl.error(Cl.uint(101));
const ERR_INVALID_OUTCOME = Cl.error(Cl.uint(103));
const ERR_STAKE_TOO_LOW = Cl.error(Cl.uint(104));
const ERR_STAKE_TOO_HIGH = Cl.error(Cl.uint(105));
const ERR_MARKET_CLOSED = Cl.error(Cl.uint(106));
const ERR_MARKET_NOT_RESOLVED = Cl.error(Cl.uint(107));
const ERR_NO_WINNINGS = Cl.error(Cl.uint(108));
const ERR_ALREADY_CLAIMED = Cl.error(Cl.uint(109));
const ERR_INVALID_ORACLE = Cl.error(Cl.uint(110));
const ERR_MARKET_LOCKED = Cl.error(Cl.uint(111));
const ERR_PAUSED = Cl.error(Cl.uint(113));
const ERR_INVALID_FEE = Cl.error(Cl.uint(114));
const ERR_INVALID_PRINCIPAL = Cl.error(Cl.uint(116));
const ERR_INVALID_OUTCOME_COUNT = Cl.error(Cl.uint(117));
const ERR_INVALID_INPUT = Cl.error(Cl.uint(118));
const ERR_INVALID_DATE = Cl.error(Cl.uint(119));

describe("Oracle Market Contract Tests", () => {
  
  describe("Contract Initialization", () => {
    it("should initialize with correct default values", () => {
      const contractInfo = simnet.callReadOnlyFn(
        "oracle-market",
        "get-contract-info",
        [],
        deployer
      );
      
      expect(contractInfo.result).toBeOk(
        Cl.tuple({
          paused: Cl.bool(false),
          oracle: Cl.principal(deployer),
          treasury: Cl.principal(deployer),
          "fee-bps": Cl.uint(300),
          "next-market-id": Cl.uint(0)
        })
      );
    });
  });

  describe("Admin Functions", () => {
    it("should allow owner to set oracle address", () => {
      const result = simnet.callPublicFn(
        "oracle-market",
        "set-oracle-address",
        [Cl.principal(oracle)],
        deployer
      );
      
      expect(result.result).toBeOk(Cl.bool(true));
    });

    it("should not allow non-owner to set oracle address", () => {
      const result = simnet.callPublicFn(
        "oracle-market",
        "set-oracle-address",
        [Cl.principal(wallet1)],
        wallet1
      );
      
      expect(result.result).toBeErr(Cl.uint(100));
    });

    it("should allow owner to set treasury address", () => {
      const result = simnet.callPublicFn(
        "oracle-market",
        "set-treasury-address",
        [Cl.principal(wallet1)],
        deployer
      );
      
      expect(result.result).toBeOk(Cl.bool(true));
    });

    it("should allow owner to set platform fee", () => {
      const result = simnet.callPublicFn(
        "oracle-market",
        "set-platform-fee",
        [Cl.uint(500)], // 5%
        deployer
      );
      
      expect(result.result).toBeOk(Cl.bool(true));
    });

     it("should not allow platform fee above 10%", () => {
      const result = simnet.callPublicFn(
        "oracle-market",
        "set-platform-fee",
        [Cl.uint(1001)], // 10.01%
        deployer
      );
      
      expect(result.result).toBeErr(Cl.uint(114)); // ERR-INVALID-FEE
    });

    it("should allow owner to toggle pause", () => {
      const result = simnet.callPublicFn(
        "oracle-market",
        "toggle-pause",
        [],
        deployer
      );
      
      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe("Market Creation", () => {
    it("should create a market with valid parameters", () => {
      const currentBlock = simnet.blockHeight;
      const lockDate = currentBlock + 100;
      const resolutionDate = currentBlock + 200;

      const result = simnet.callPublicFn(
        "oracle-market",
        "create-market",
        [
          Cl.stringAscii("Who will win the 2026 election?"),
          Cl.stringUtf8("Presidential election prediction market"),
          Cl.stringAscii("Politics"),
          Cl.list([
            Cl.stringUtf8("Candidate A"),
            Cl.stringUtf8("Candidate B"),
            Cl.stringUtf8("Other")
          ]),
          Cl.uint(resolutionDate),
          Cl.uint(lockDate)
        ],
        deployer
      );

      expect(result.result).toBeOk(Cl.uint(0));
    });

    it("should not allow non-owner to create market", () => {
      const currentBlock = simnet.blockHeight;
      const lockDate = currentBlock + 100;
      const resolutionDate = currentBlock + 200;

      const result = simnet.callPublicFn(
        "oracle-market",
        "create-market",
        [
          Cl.stringAscii("Test Market"),
          Cl.stringUtf8("Test Description"),
          Cl.stringAscii("Test"),
          Cl.list([
            Cl.stringUtf8("Option 1"),
            Cl.stringUtf8("Option 2")
          ]),
          Cl.uint(resolutionDate),
          Cl.uint(lockDate)
        ],
        wallet1
      );

      expect(result.result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });

    it("should reject market with less than 2 outcomes", () => {
      const currentBlock = simnet.blockHeight;
      const lockDate = currentBlock + 100;
      const resolutionDate = currentBlock + 200;

      const result = simnet.callPublicFn(
        "oracle-market",
        "create-market",
        [
          Cl.stringAscii("Invalid Market"),
          Cl.stringUtf8("Only one outcome"),
          Cl.stringAscii("Test"),
          Cl.list([Cl.stringUtf8("Only Option")]),
          Cl.uint(resolutionDate),
          Cl.uint(lockDate)
        ],
        deployer
      );

      expect(result.result).toBeErr(Cl.uint(117)); // ERR-INVALID-OUTCOME-COUNT
    });

    it("should reject market with lock date after resolution date", () => {
      const currentBlock = simnet.blockHeight;
      const lockDate = currentBlock + 200;
      const resolutionDate = currentBlock + 100;

      const result = simnet.callPublicFn(
        "oracle-market",
        "create-market",
        [
          Cl.stringAscii("Invalid Market"),
          Cl.stringUtf8("Bad dates"),
          Cl.stringAscii("Test"),
          Cl.list([
            Cl.stringUtf8("Option 1"),
            Cl.stringUtf8("Option 2")
          ]),
          Cl.uint(resolutionDate),
          Cl.uint(lockDate)
        ],
        deployer
      );

      expect(result.result).toBeErr(Cl.uint(119)); // ERR-INVALID-DATE
    });
  });

  describe("Staking", () => {
    beforeEach(() => {
      // Create a test market before each staking test
      const currentBlock = simnet.blockHeight;
      const lockDate = currentBlock + 100;
      const resolutionDate = currentBlock + 200;

      simnet.callPublicFn(
        "oracle-market",
        "create-market",
        [
          Cl.stringAscii("Test Market"),
          Cl.stringUtf8("Test Description"),
          Cl.stringAscii("Sports"),
          Cl.list([
            Cl.stringUtf8("Team A"),
            Cl.stringUtf8("Team B")
          ]),
          Cl.uint(resolutionDate),
          Cl.uint(lockDate)
        ],
        deployer
      );
    });

    it("should allow user to place a valid stake", () => {
      const result = simnet.callPublicFn(
        "oracle-market",
        "place-stake",
        [
          Cl.uint(0), // market-id
          Cl.uint(0), // outcome-index
          Cl.uint(MIN_STAKE) // stake amount
        ],
        wallet1
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it("should reject stake below minimum", () => {
      const result = simnet.callPublicFn(
        "oracle-market",
        "place-stake",
        [
          Cl.uint(0),
          Cl.uint(0),
          Cl.uint(MIN_STAKE - 1)
        ],
        wallet1
      );

      expect(result.result).toBeErr(Cl.uint(104)); // ERR-STAKE-TOO-LOW
    });

    it("should reject stake above maximum", () => {
      const result = simnet.callPublicFn(
        "oracle-market",
        "place-stake",
        [
          Cl.uint(0),
          Cl.uint(0),
          Cl.uint(MAX_STAKE + 1)
        ],
        wallet1
      );

      expect(result.result).toBeErr(Cl.uint(105)); // ERR-STAKE-TOO-HIGH
    });

    it("should reject stake on invalid outcome", () => {
      const result = simnet.callPublicFn(
        "oracle-market",
        "place-stake",
        [
          Cl.uint(0),
          Cl.uint(5), // Invalid outcome index
          Cl.uint(MIN_STAKE)
        ],
        wallet1
      );

      expect(result.result).toBeErr(Cl.uint(103)); // ERR-INVALID-OUTCOME
    });

     it("should allow multiple users to stake on different outcomes", () => {
      const stake1 = simnet.callPublicFn(
        "oracle-market",
        "place-stake",
        [Cl.uint(0), Cl.uint(0), Cl.uint(MIN_STAKE * 2)],
        wallet1
      );

      const stake2 = simnet.callPublicFn(
        "oracle-market",
        "place-stake",
        [Cl.uint(0), Cl.uint(1), Cl.uint(MIN_STAKE * 3)],
        wallet2
      );

      expect(stake1.result).toBeOk(Cl.bool(true));
      expect(stake2.result).toBeOk(Cl.bool(true));
    });

    it("should update outcome pool totals correctly", () => {
      simnet.callPublicFn(
        "oracle-market",
        "place-stake",
        [Cl.uint(0), Cl.uint(0), Cl.uint(MIN_STAKE * 5)],
        wallet1
      );

      const poolInfo = simnet.callReadOnlyFn(
        "oracle-market",
        "get-outcome-pool-info",
        [Cl.uint(0), Cl.uint(0)],
        wallet1
      );

      expect(poolInfo.result).toBeOk(
        Cl.tuple({
          "total-staked": Cl.uint(MIN_STAKE * 5),
          "staker-count": Cl.uint(1)
        })
      );
    });
  });

  describe("Market Locking and Resolution", () => {
    let marketId: number;
    let lockDate: number;
    let resolutionDate: number;

    beforeEach(() => {
      // Set oracle address
      simnet.callPublicFn(
        "oracle-market",
        "set-oracle-address",
        [Cl.principal(oracle)],
        deployer
      );

      const currentBlock = simnet.blockHeight;
      lockDate = currentBlock + 10;
      resolutionDate = currentBlock + 20;
      marketId = 0;

      // Create market
      simnet.callPublicFn(
        "oracle-market",
        "create-market",
        [
          Cl.stringAscii("Test Market"),
          Cl.stringUtf8("Test Description"),
          Cl.stringAscii("Sports"),
          Cl.list([
            Cl.stringUtf8("Team A"),
            Cl.stringUtf8("Team B")
          ]),
          Cl.uint(resolutionDate),
          Cl.uint(lockDate)
        ],
        deployer
      );

      // Place some stakes
      simnet.callPublicFn(
        "oracle-market",
        "place-stake",
        [Cl.uint(marketId), Cl.uint(0), Cl.uint(MIN_STAKE * 10)],
        wallet1
      );

      simnet.callPublicFn(
        "oracle-market",
        "place-stake",
        [Cl.uint(marketId), Cl.uint(1), Cl.uint(MIN_STAKE * 5)],
        wallet2
      );
    });

     it("should allow oracle to lock market after lock date", () => {
      // Advance to lock date
      simnet.mineEmptyBlocks(11);

      const result = simnet.callPublicFn(
        "oracle-market",
        "lock-market",
        [Cl.uint(marketId)],
        oracle
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it("should not allow locking before lock date", () => {
      const result = simnet.callPublicFn(
        "oracle-market",
        "lock-market",
        [Cl.uint(marketId)],
        oracle
      );

      expect(result.result).toBeErr(Cl.uint(119)); // ERR-INVALID-DATE
    });

    it("should not allow non-oracle to lock market", () => {
      simnet.mineEmptyBlocks(11);

      const result = simnet.callPublicFn(
        "oracle-market",
        "lock-market",
        [Cl.uint(marketId)],
        wallet1
      );

      expect(result.result).toBeErr(Cl.uint(100)); // ERR-NOT-AUTHORIZED
    });

    it("should allow oracle to resolve market", () => {
      // Advance to resolution date
      simnet.mineEmptyBlocks(21);

      const result = simnet.callPublicFn(
        "oracle-market",
        "resolve-market",
        [Cl.uint(marketId), Cl.uint(0)], // Team A wins
        oracle
      );

      expect(result.result).toBeOk(Cl.bool(true));
    });

    it("should not allow non-oracle to resolve market", () => {
      simnet.mineEmptyBlocks(21);

      const result = simnet.callPublicFn(
        "oracle-market",
        "resolve-market",
        [Cl.uint(marketId), Cl.uint(0)],
        wallet1
      );

      expect(result.result).toBeErr(Cl.uint(110)); // ERR-INVALID-ORACLE
    });

    it("should reject staking after market is locked", () => {
      simnet.mineEmptyBlocks(11);
      
      simnet.callPublicFn(
        "oracle-market",
        "lock-market",
        [Cl.uint(marketId)],
        oracle
      );

      const result = simnet.callPublicFn(
        "oracle-market",
        "place-stake",
        [Cl.uint(marketId), Cl.uint(0), Cl.uint(MIN_STAKE)],
        wallet3
      );

      expect(result.result).toBeErr(Cl.uint(106)); // ERR-MARKET-CLOSED (locked market prevents staking)
    });
  });

  describe("Claiming Winnings", () => {
    let marketId: number;

    beforeEach(() => {
      // Set oracle
      simnet.callPublicFn(
        "oracle-market",
        "set-oracle-address",
        [Cl.principal(oracle)],
        deployer
      );