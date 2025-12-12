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