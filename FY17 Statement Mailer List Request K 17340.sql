USE OSUF_RE_DW


/*============================================================================================
--
--Gifts in the Comp Giving table  (keep)
--
============================================================================================*/

--Delete the #temp table if it exists
IF OBJECT_ID('tempdb..#LTOBGifts') IS NOT NULL
    DROP TABLE        #LTOBGifts
GO

CREATE TABLE #LTOBGifts
								(
									  CGFactID         INT          NOT NULL PRIMARY KEY CLUSTERED
									, GiftFactID       INT          NOT NULL
									, ConstituentDimID INT          NOT NULL
									, Amount           MONEY        NOT NULL
									, Fund             VARCHAR(20)  NOT NULL
									, GiftFiscalYear   INT          NOT NULL
									, GiftType         VARCHAR(100) NOT NULL
									, GiftDate         DATETIME     NOT NULL
									, IsAGGift         VARCHAR(3)   NOT NULL
									, AppealIdentifier VARCHAR(20)
									, REGiftType       VARCHAR(50)  NOT NULL
								)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #LTOBGifts', 0, 1, 56) WITH NOWAIT
INSERT INTO            #LTOBGifts
SELECT
  CG.CGFactID
, CG.GiftFactID
, CG.ConstituentDimID
, CG.Amount
, CG.Fund
, CG.GiftFiscalYear
, CG.GiftType
, CG.GiftDate 
, OG.IsAGGift
, OG.AppealIdentifier
, GT.GiftType AS REGiftType

FROM 
  dbo.FACT_OSUF_ComprehensiveGiving AS CG
											INNER JOIN dbo.DIM_Constituent AS  C ON CG.ConstituentDimID = C.ConstituentDimID
											INNER JOIN dbo.FACT_OSUF_Gift  AS OG ON CG.GiftFactID = OG.GiftFactID
											INNER JOIN dbo.FACT_Gift       AS  G ON CG.GiftFactID = G.GiftFactID
											INNER JOIN dbo.DIM_GiftType    AS GT ON G.GiftTypeDimID = GT.GiftTypeDimID

WHERE
    C.KeyIndicator = 'I'
AND C.IsDeceased = 'No'
AND C.IsInactive = 'No'

--Speed trick, create an index
CREATE INDEX IDX_CompGiving_Multi1 ON #LTOBGifts(GiftFactID,ConstituentDimID)


select * from #LTOBGifts



/*============================================================================================
--
--Map Realized Planned Gift to Planned Gift Date
--
============================================================================================*/

--Delete the #temp table if it exists
IF OBJECT_ID('tempdb..#RealizedPlannedGiftPlannedGiftDate') IS NOT NULL
    DROP TABLE        #RealizedPlannedGiftPlannedGiftDate
GO

CREATE TABLE #RealizedPlannedGiftPlannedGiftDate
													(
														  GiftFactID            INT      NOT NULL PRIMARY KEY CLUSTERED
														, PlannedGiftDate       DATETIME NOT NULL
														, PlannedGiftFiscalYear INT      NOT NULL 
													)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #RealizedPlannedGiftPlannedGiftDate', 0, 1, 56) WITH NOWAIT
INSERT INTO            #RealizedPlannedGiftPlannedGiftDate

SELECT 
  GiftFactID
, PlannedGiftDate
, D.FiscalYear AS PlannedGiftFiscalYear

FROM 
	(
		SELECT
		  CG.GiftFactID

		, MIN(CASE 
						WHEN RealizedPGOrigionalPGG.GiftFactID IS NOT NULL THEN G.GiftDate
						WHEN CG.GiftDate >= PlannedGiftDates.LastGiftDate THEN PlannedGiftDates.LastGiftDate
						ELSE COALESCE(PlannedGiftDates.FirstGiftDate, '1900-01-01 00:00:00.000')
			  END )  AS PlannedGiftDate


		FROM
		  #LTOBGifts AS CG
																	
																	
																			--Gift Information
																			INNER JOIN dbo.FACT_Gift AS G ON CG.GiftFactID = G.GiftFactID

																			--Realized Planned Gift Code2
																			INNER JOIN
																							( 
																								SELECT DISTINCT
																								  GiftFactID
																								FROM dbo.FACT_GiftAttribute
																								WHERE AttributeCategory = 'Planned Gift Realized'
																							) AS RPG ON CG.GiftFactID = RPG.GiftFactID

																			--Realized Planned Gift Code2
																			LEFT OUTER JOIN
																							( 
																								SELECT DISTINCT
																								  CG.ConstituentDimID
																								, MAX(CG.GiftDate) AS LastGiftDate
																								, MIN(CG.GiftDate) AS FirstGiftDate

																								FROM 
																								  #LTOBGifts AS CG
																														INNER JOIN dbo.FACT_Gift AS G ON CG.GiftFactID = G.GiftFactID
																														INNER JOIN dbo.DIM_GiftType AS GT ON G.GiftTypeDimID = GT.GiftTypeDimID
																										
																								WHERE 
																									GT.GiftType = 'Planned Gift'

																								GROUP BY 
																								  CG.ConstituentDimID
																							) AS PlannedGiftDates ON CG.ConstituentDimID = PlannedGiftDates.ConstituentDimID


																			--Gift Information for the origional planned gift of a realized planned gift
																			LEFT OUTER JOIN dbo.FACT_Gift RealizedPGOrigionalPGG ON G.PlannedGiftID = RealizedPGOrigionalPGG.GiftSystemID

		WHERE 
			RPG.GiftFactID IS NOT NULL
		AND CG.ConstituentDimID = G.ConstituentDimID

		GROUP BY
		  CG.GiftFactID
	) AS Q
			INNER JOIN dbo.DIM_Date AS D ON Q.PlannedGiftDate = D.ActualDate





/*============================================================================================
--
--FY17 Projected Gifts that tied to a commitment from FY15 or older
--
============================================================================================*/

--Delete the #temp table if it exists
IF OBJECT_ID('tempdb..#FY17ProjectGifts') IS NOT NULL
    DROP TABLE        #FY17ProjectGifts
GO

CREATE TABLE #FY17ProjectGifts
								(
									  CGFactID         INT          NOT NULL PRIMARY KEY CLUSTERED
									, GiftFactID       INT          NOT NULL
									, ConstituentDimID INT          NOT NULL
									, Amount           MONEY        NOT NULL
									, Fund             VARCHAR(20)  NOT NULL
									, GiftFiscalYear   INT          NOT NULL
									, GiftType         VARCHAR(100) NOT NULL
									, GiftDate         DATETIME     NOT NULL
									, IsAGGift         VARCHAR(3)   NOT NULL
									, AppealIdentifier VARCHAR(20)
									, REGiftType       VARCHAR(50)  NOT NULL
								)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #FY17ProjectGifts', 0, 1, 56) WITH NOWAIT
INSERT INTO            #FY17ProjectGifts
SELECT
  -1 * AP.CAPDimID AS CGFactID
, -1 * AP.CAPDimID AS GiftFactID  --This are projected gifts, no GiftFactID so we are using a fake one.
, C.ConstituentDimID
, AP.GiftAmount AS Amount
, AP.FundIdentifier AS Fund
, AP.FiscalYear AS GiftFiscalYear
, 'Annual Projection' AS GiftType
, AP.GiftDate
, AP.IsAGGift
, AP.AppealIdentifier
, 'Annual Projection' AS REGiftType 

FROM 
	[Report_DW].[dbo].[OSUF_Comprehensive_Annual_Projection] AS AP
																INNER JOIN dbo.DIM_Constituent AS C ON AP.ConstituentID = C.ConstituentID

WHERE 
	AP.GiftAmount > 0
AND AP.GiftCommitmentDate < '2016-07-01 00:00:00.000'
ANd AP.GiftFactID IS NULL
AND AP.FiscalYear = 2017
AND C.IsDeceased = 'No'
AND C.IsInactive = 'No'


/*============================================================================================
--
--Gift Club Giving by Fiscal Year (takes about 1 min to run)
--
============================================================================================*/

--Delete the #temp table if it exists
IF OBJECT_ID('tempdb..#LTOBGivingPerFiscalYear') IS NOT NULL
    DROP TABLE        #LTOBGivingPerFiscalYear
GO


CREATE TABLE #LTOBGivingPerFiscalYear
									(
										  PKID              INT   NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
										, ConstituentDimID  INT   NOT NULL
										, FiscalYear        INT   NOT NULL
										, Amount            MONEY NOT NULL
									)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #LTOBGivingPerFiscalYear', 0, 1, 56) WITH NOWAIT
--Start Date for Loop
DECLARE @FY INT;
SET @FY = 2016;


--The start of the loop Loop
WHILE @FY <= 2017  
BEGIN
--The looping begins here
INSERT INTO #LTOBGivingPerFiscalYear --Insert results into temp table
SELECT 
  Q.ConstituentDimID
, @FY AS FiscalYear
, SUM(Q.Amount) AS Amount

FROM 
	(	
		SELECT 
		  *

		FROM
			(
				
				--There is a chance when a pledge payment pays multiable installments a duplicate row can occure. This removes the dups.
				SELECT
				  *
				, ROW_NUMBER() OVER( PARTITION BY QL1.ConstituentDimID, QL1.CGFactID ORDER BY QL1.Amount DESC ) AS Seq

				FROM
					(
						SELECT 
						  CG.ConstituentDimID
						, CG.CGFactID
						, CG.GiftFactID
						, CG.GiftType AS GiftTypeSummary
						, CASE 
								WHEN GT.GiftType = 'Pledge'         THEN COALESCE(GC.Amount, 0) - COALESCE(GC.WriteOffAmount, 0)
								WHEN GT.GiftType = 'MG Pledge'      THEN COALESCE(GC.Amount, 0) - COALESCE(GC.WriteOffAmount, 0)
								WHEN GT.GiftType = 'Recurring Gift' THEN COALESCE(RGwED.Amount, 0) - COALESCE(RGwED.WriteOffs, 0)
								WHEN GT.GiftType = 'Planned Gift'   THEN G.Amount
								ELSE CG.Amount
						  END AS Amount

						, CG.GiftDate
						, CG.Fund
						, GT.GiftType
						, @FY AS GiftFiscalYear

						, CASE 
								
								WHEN GT.GiftType = 'Planned Gift' THEN 'Include'
								WHEN RPG.GiftFactID IS NOT NULL AND CG.GiftFiscalYear = RPG.PlannedGiftFiscalYear  THEN 'Exclude - Realized Planned Gift made in the same year as Planned Gift'
								WHEN RPG.GiftFactID IS NOT NULL AND CG.GiftFiscalYear <> RPG.PlannedGiftFiscalYear THEN 'Include'
				
								WHEN GT.GiftType = 'Pledge' THEN 'Include'
				
								WHEN GT.GiftType LIKE 'Pay-%' AND CG.Fund IN ('11-00100', '12-00200')                                                                  THEN 'Include'  --Comperhensive Giving does not have the pledges for membership dues. This allows the payments to be included sicne the pledge isnt.
								WHEN GT.GiftType LIKE 'Pay-%' AND CG.GiftFiscalYear = InstallmentOrigionalPledgeDate.FiscalYear AND GiftCredits.GiftFactID IS NOT NULL THEN 'Exclude - Pledge Payment made in the same year as the pledge'
								WHEN GT.GiftType LIKE 'Pay-%' AND CG.GiftFiscalYear <> InstallmentOrigionalPledgeDate.FiscalYear                                       THEN 'Include'

								WHEN GT.GiftType = 'Recurring Gift' THEN 'Include'
								
								WHEN GT.GiftType = 'Recurring Gift Pay-Cash' AND GiftCredits.GiftFactID IS NULL                                 THEN 'Include'  --Recurring gift with out an end date
								WHEN GT.GiftType = 'Recurring Gift Pay-Cash' AND CG.GiftFiscalYear = InstallmentOrigionalPledgeDate.FiscalYear  THEN 'Exclude - Recurring Gift Payment made in the same year as the pledge'	
								WHEN GT.GiftType = 'Recurring Gift Pay-Cash' AND CG.GiftFiscalYear <> InstallmentOrigionalPledgeDate.FiscalYear THEN 'Include'

								WHEN GT.GiftType = 'MG Pledge' THEN 'Include'
				
								WHEN GT.GiftType LIKE 'MG Pay%' AND CG.GiftFiscalYear = InstallmentOrigionalPledgeDate.FiscalYear  THEN 'Exclude - Matching Gift Payment made in the same year as the pledge'
								WHEN GT.GiftType LIKE 'MG Pay%' AND CG.GiftFiscalYear <> InstallmentOrigionalPledgeDate.FiscalYear THEN 'Include'

								ELSE 'Include'  --Need to account for recurring gifts and matching gifts
						  END AS IncludeGiftStatus

						FROM 
						  #LTOBGifts AS CG
																	--Gift Information
																	INNER JOIN dbo.FACT_Gift AS G ON CG.GiftFactID = G.GiftFactID
											
																	--Gift Type Information
																	INNER JOIN dbo.DIM_GiftType AS GT ON G.GiftTypeDimID = GT.GiftTypeDimID
											
																	--Recurring Gift with an End Date
																	LEFT OUTER JOIN dbo.[OSUF_RecurringGift_withEndDate] AS RGwED ON CG.GiftFactID = RGwED.GiftFactID

																	--Gift Commitment (pledge, MG Pledge, Recurring Gifts)
																	LEFT OUTER JOIN dbo.FACT_GiftCommitment AS GC ON CG.GiftFactID = GC.GiftFactID
											
																	--Payments to Commitments (pledge, MG Pledge, Recurring Gifts) information
																	LEFT OUTER JOIN dbo.FACT_GiftInstallmentPayment AS GIP ON CG.GiftFactID = GIP.GiftPaymentFactID
											
																	--Origional Gift Commitment (pledge, MG Pledge, Recurring Gifts) Information
																	LEFT OUTER JOIN dbo.FACT_Gift AS InstallmentOrigionalPledge ON GIP.GiftCommitmentSystemID = InstallmentOrigionalPledge.GiftSystemID
											
																	--Date information for origional gift commitment (pledge, MG Pledge, Recurring Gifts)
																	LEFT OUTER JOIN dbo.DIM_Date AS InstallmentOrigionalPledgeDate ON InstallmentOrigionalPledge.GiftDateDimID = InstallmentOrigionalPledgeDate.DateDimID

																	--List of Gift commitments a constituent gets credit for
																	LEFT OUTER JOIN
																					(
																						SELECT DISTINCT 
																						  ConstituentDimID
																						, GiftFactID

																						FROM
																						  #LTOBGifts
																					) AS GiftCredits ON CG.ConstituentDimID = GiftCredits.ConstituentDimID AND InstallmentOrigionalPledge.GiftFactID = GiftCredits.GiftFactID

																	--Realized Planned Gift Details
																	LEFT OUTER JOIN #RealizedPlannedGiftPlannedGiftDate AS RPG ON CG.GiftFactID = RPG.GiftFactID

						WHERE 
							CG.GiftFiscalYear = @FY  --Fiscal year is determinded by a variable



						UNION ALL
						--Annual Projection
						SELECT 
						  ConstituentDimID
						, GiftFactID
						, CGFactID
						, 'Projection Summary' AS GiftTypeSummary
						, Amount
						--, CASE WHEN IsAGGift = 'Yes' THEN Amount ELSE 0 END AS AGAmount
						, GiftDate
						, Fund
						, GiftType
						, GiftFiscalYear AS GiftFiscalYear
						, 'Include' AS IncludeGiftStatus	
	
						FROM 
						  #FY17ProjectGifts

						WHERE
							@FY = GiftFiscalYear


				) AS QL1

		    ) AS QL2

		WHERE QL2.Seq = 1

	) AS Q
			INNER JOIN dbo.DIM_Constituent AS C ON Q.ConstituentDimID = C.ConstituentDimID

WHERE
    C.KeyIndicator = 'I'
AND C.IsDeceased = 'No'
AND C.IsInactive = 'No'
AND Q.IncludeGiftStatus = 'Include'
AND Q.Amount > 0

GROUP BY
  Q.ConstituentDimID

HAVING 
    SUM(Q.Amount) > 0

   SET @FY = @FY + 1;  --Updating the variable that controls the fiscal year
END; --This is where the loop ends and will start over again










RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #LTOBGivingPerFiscalYear  FY06 and FY15', 0, 1, 56) WITH NOWAIT
--Start Date for Loop
SET @FY = 2006;


--The start of the loop Loop
WHILE @FY <= 2015  
BEGIN
--The looping begins here
INSERT INTO #LTOBGivingPerFiscalYear --Insert results into temp table
SELECT 
  Q.ConstituentDimID
, @FY AS FiscalYear
, SUM(Q.Amount) AS Amount

FROM 
	(	
		SELECT 
		  *

		FROM
			(
				
				--There is a chance when a pledge payment pays multiable installments a duplicate row can occure. This removes the dups.
				SELECT
				  *
				, ROW_NUMBER() OVER( PARTITION BY QL1.ConstituentDimID, QL1.CGFactID ORDER BY QL1.Amount DESC ) AS Seq

				FROM
					(
						SELECT 
						  CG.ConstituentDimID
						, CG.CGFactID
						, CG.GiftFactID
						, CG.GiftType AS GiftTypeSummary
						, CASE 
								WHEN GT.GiftType = 'Pledge'         THEN COALESCE(GC.Amount, 0) - COALESCE(GC.WriteOffAmount, 0)
								WHEN GT.GiftType = 'MG Pledge'      THEN COALESCE(GC.Amount, 0) - COALESCE(GC.WriteOffAmount, 0)
								WHEN GT.GiftType = 'Recurring Gift' THEN COALESCE(RGwED.Amount, 0) - COALESCE(RGwED.WriteOffs, 0)
								WHEN GT.GiftType = 'Planned Gift'   THEN G.Amount
								ELSE CG.Amount
						  END AS Amount

						, CG.GiftDate
						, CG.Fund
						, GT.GiftType
						, @FY AS GiftFiscalYear

						, CASE 
								
								WHEN GT.GiftType = 'Planned Gift' THEN 'Include'
								WHEN RPG.GiftFactID IS NOT NULL AND CG.GiftFiscalYear = RPG.PlannedGiftFiscalYear  THEN 'Exclude - Realized Planned Gift made in the same year as Planned Gift'
								
								WHEN RPG.GiftFactID IS NOT NULL AND CG.GiftFiscalYear-1 = RPG.PlannedGiftFiscalYear
															    AND CG.Giftdate BETWEEN CAST(CAST(@FY AS VARCHAR(4)) + '-07-01 00:00:00.000' AS DATETIME) AND CAST(CAST(@FY AS VARCHAR(4)) + '-07-21 00:00:00.000' AS DATETIME)      
																
																	THEN 'Exclude - Realize Planned Gift made in the following fiscal but up to 7/21'
								
								
								WHEN RPG.GiftFactID IS NOT NULL AND CG.GiftFiscalYear <> RPG.PlannedGiftFiscalYear THEN 'Include'								
								
												
								WHEN GT.GiftType = 'Pledge' THEN 'Include'
				
								WHEN GT.GiftType LIKE 'Pay-%' AND CG.Fund IN ('11-00100', '12-00200') THEN 'Include'  --Comperhensive Giving does not have the pledges for membership dues. This allows the payments to be included sicne the pledge isnt.
				
								WHEN GT.GiftType LIKE 'Pay-%' AND CG.GiftFiscalYear = InstallmentOrigionalPledgeDate.FiscalYear AND GiftCredits.GiftFactID IS NOT NULL THEN 'Exclude - Pledge Payment made in the same year as the pledge'

								WHEN GT.GiftType LIKE 'Pay-%'  AND CG.GiftFiscalYear-1 = InstallmentOrigionalPledgeDate.FiscalYear 
																AND GiftCredits.GiftFactID IS NOT NULL
															   AND CG.Giftdate BETWEEN CAST(CAST(@FY AS VARCHAR(4)) + '-07-01 00:00:00.000' AS DATETIME) AND CAST(CAST(@FY AS VARCHAR(4)) + '-07-21 00:00:00.000' AS DATETIME)      
																
																	THEN 'Exclude - Pledge Payment made in the following fiscal but up to 7/21'
								WHEN GT.GiftType LIKE 'Pay-%' AND CG.GiftFiscalYear <> InstallmentOrigionalPledgeDate.FiscalYear THEN 'Include'

		
								WHEN GT.GiftType = 'Recurring Gift' THEN 'Include'
								WHEN GT.GiftType = 'Recurring Gift Pay-Cash' AND GiftCredits.GiftFactID IS NULL THEN 'Include' -- Recurring Gift with out an end date no need to consider the origional pledge date
								WHEN GT.GiftType = 'Recurring Gift Pay-Cash' AND CG.GiftFiscalYear = InstallmentOrigionalPledgeDate.FiscalYear THEN 'Exclude - Recurring Gift Payment made in the same year as the pledge'
								WHEN GT.GiftType = 'Recurring Gift Pay-Cash' AND CG.GiftFiscalYear-1 = InstallmentOrigionalPledgeDate.FiscalYear 
															   AND CG.Giftdate BETWEEN CAST(CAST(@FY AS VARCHAR(4)) + '-07-01 00:00:00.000' AS DATETIME) AND CAST(CAST(@FY AS VARCHAR(4)) + '-07-21 00:00:00.000' AS DATETIME)      
																
																	THEN 'Exclude - Recurring Gift Payment made in the following fiscal but up to 7/21'				
				
				
								WHEN GT.GiftType = 'Recurring Gift Pay-Cash' AND CG.GiftFiscalYear <> InstallmentOrigionalPledgeDate.FiscalYear THEN 'Include'

								WHEN GT.GiftType = 'MG Pledge' THEN 'Include'
				
								WHEN GT.GiftType LIKE 'MG Pay%' AND CG.GiftFiscalYear = InstallmentOrigionalPledgeDate.FiscalYear THEN 'Exclude - Matching Gift Payment made in the same year as the pledge'
								WHEN GT.GiftType LIKE 'MG Pay%' AND CG.GiftFiscalYear-1 = InstallmentOrigionalPledgeDate.FiscalYear 
																AND CG.Giftdate BETWEEN CAST(CAST(@FY AS VARCHAR(4)) + '-07-01 00:00:00.000' AS DATETIME) AND CAST(CAST(@FY AS VARCHAR(4)) + '-07-21 00:00:00.000' AS DATETIME)      
																
																	THEN 'Exclude - Matching Gift Payment made in the following fiscal but up to 7/21'		

								WHEN GT.GiftType LIKE 'MG Pay%' AND CG.GiftFiscalYear <> InstallmentOrigionalPledgeDate.FiscalYear THEN 'Include'

								ELSE 'Include' 
						  END AS IncludeGiftStatus

						FROM 
						  #LTOBGifts AS CG
																	
																	--Gift Information
																	INNER JOIN dbo.FACT_Gift AS G ON CG.GiftFactID = G.GiftFactID
											
																	--Gift Type Information
																	INNER JOIN dbo.DIM_GiftType AS GT ON G.GiftTypeDimID = GT.GiftTypeDimID
											
																	--Recurring Gift with an End Date
																	LEFT OUTER JOIN dbo.[OSUF_RecurringGift_withEndDate] AS RGwED ON CG.GiftFactID = RGwED.GiftFactID

																	--Gift Commitment (pledge, MG Pledge, Recurring Gifts)
																	LEFT OUTER JOIN dbo.FACT_GiftCommitment AS GC ON CG.GiftFactID = GC.GiftFactID
											
																	--Payments to Commitments (pledge, MG Pledge, Recurring Gifts) information
																	LEFT OUTER JOIN dbo.FACT_GiftInstallmentPayment AS GIP ON CG.GiftFactID = GIP.GiftPaymentFactID
											
																	--Origional Gift Commitment (pledge, MG Pledge, Recurring Gifts) Information
																	LEFT OUTER JOIN dbo.FACT_Gift AS InstallmentOrigionalPledge ON GIP.GiftCommitmentSystemID = InstallmentOrigionalPledge.GiftSystemID
											
																	--Date information for origional gift commitment (pledge, MG Pledge, Recurring Gifts)
																	LEFT OUTER JOIN dbo.DIM_Date AS InstallmentOrigionalPledgeDate ON InstallmentOrigionalPledge.GiftDateDimID = InstallmentOrigionalPledgeDate.DateDimID

																	--List of Gift commitments a constituent gets credit for
																	LEFT OUTER JOIN
																					(
																						SELECT DISTINCT 
																						  ConstituentDimID
																						, GiftFactID

																						FROM
																						  #LTOBGifts
																					) AS GiftCredits ON CG.ConstituentDimID = GiftCredits.ConstituentDimID AND InstallmentOrigionalPledge.GiftFactID = GiftCredits.GiftFactID

																	--Realized Planned Gift Details
																	LEFT OUTER JOIN #RealizedPlannedGiftPlannedGiftDate AS RPG ON CG.GiftFactID = RPG.GiftFactID
																	
																	
						WHERE 
							CG.GiftDate BETWEEN CAST(CAST(@FY-1 AS VARCHAR(4)) + '-07-01 00:00:00.000' AS DATETIME) AND CAST(CAST(@FY AS VARCHAR(4)) + '-07-20 00:00:00.000' AS DATETIME)  --Fiscal year is determinded by a variable
				) AS QL1

		    ) AS QL2

		WHERE QL2.Seq = 1

	) AS Q
			INNER JOIN dbo.DIM_Constituent AS C ON Q.ConstituentDimID = C.ConstituentDimID

WHERE
    C.KeyIndicator = 'I'
AND C.IsDeceased = 'No'
AND C.IsInactive = 'No'
AND Q.IncludeGiftStatus = 'Include'
AND Q.Amount > 0

GROUP BY
  Q.ConstituentDimID

HAVING 
    SUM(Q.Amount) > 0

   SET @FY = @FY + 1;  --Updating the variable that controls the fiscal year
END; --This is where the loop ends and will start over again

/*============================================================================================
--
--Include List
--
============================================================================================*/

--Delete the #temp table if it exists
IF OBJECT_ID('tempdb..#IncludeList') IS NOT NULL
  DROP TABLE          #IncludeList
GO

CREATE TABLE #IncludeList
                         (
						      ConstituentDimID INT NOT NULL PRIMARY KEY CLUSTERED
						 )	

RAISERROR('Populating #IncludeList',0, 1, 56) WITH NOWAIT							
INSERT INTO           #IncludeList



SELECT 
  Q.ConstituentDimID

FROM 
	(
		--FY2016 and 2017 LTOB Giving
		SELECT 
		  ConstituentDimID

		FROM
		  #LTOBGivingPerFiscalYear

		WHERE
		    FiscalYear IN (2016, 2017)

		--Has annual giving defined giving since 7/1/2006
		UNION
		SELECT 
		  ConstituentDimID
		 
		FROM
		  Report_DW.dbo.OSUF_Comp_Production_and_Receipts

		WHERE 
		    IsAGGift = 'Yes'
		AND FiscalYear BETWEEN 2006 AND 2017
		AND CGPRAmount > 0
		AND DataSource IN ('Development', 'OSUAA Membership Dues', 'Recognition Credit')	 
	) AS Q
			INNER JOIN dbo.OSUF_PrimaryConstituentCode PCC ON Q.ConstituentDimID=PCC.ConstituentDimID

WHERE 
    PCC.ConstituentCode IN ('Alumni', 'Attended', 'Friend')


/*============================================================================================

--Description: Excludelist  table 

============================================================================================*/
--Delete the #temp table if it exists
IF OBJECT_ID('tempdb..#Excludelist') IS NOT NULL
    DROP TABLE #Excludelist

	Create table #Excludelist
	                                        (
												ConstituentDimID INT NOT NULL PRIMARY KEY CLUSTERED
											)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #Excludelist', 0, 1, 56) WITH NOWAIT
INSERT INTO #Excludelist
  -- Position Excludes
SELECT 
  ConstituentDimID
							   
FROM 
  dbo.OSUF_Positions

WHERE 
    Position IN ('Principal Gift Prospect', 'Board of Governor-Current', 'Board of Governor Trustee', 'Board of Governor-Honorary Trustee', 'National Campaign Committee', 'Executive Campaign Committee')


UNION												
--  Primary Constituent Code Excludes
SELECT 
  ConstituentDimID

FROM 
  dbo.OSUF_PrimaryConstituentCode

WHERE 
	ConstituentCode IN 
					(
						           		                              
							    'Contact'
							, 'KOSU Donor'
							, 'Memorial Donor'
							, 'OSUAA Legacy'
							, 'Special Interest Donor'
							, 'Student'
							, 'Utility Record'
							, 'On Hold Record'
						) 


UNION												
-- Constituent Faculty/Staff Excludes
SELECT 
ConstituentDimID
          
FROM 
dbo.DIM_ConstituentConstitCode
          
WHERE 
	ConstituentCode='Faculty/Staff'  


UNION
--Constituents with primary constituent code of friend no giving history  
SELECT
		C.ConstituentDimID

	FROM
		dbo.DIM_Constituent AS C
								INNER JOIN dbo.OSUF_PrimaryConstituentCode AS PCC ON C.ConstituentDimID = PCC.ConstituentDimID
								INNER JOIN
										(
											SELECT DISTINCT 
												ConstituentDimID
														
											FROM 
												dbo.DIM_ConstituentConstitCode
														
											WHERE 
												ConstituentCode IN ('CVHS Client', 'OSUAA Legacy - Former', 'Faculty/Staff - Former')
										) AS SecondaryCodes ON C.ConstituentDimID = SecondaryCodes.ConstituentDimID  
								LEFT OUTER JOIN
											(
												SELECT DISTINCT 
													ConstituentDimID

												FROM 
													dbo.DIM_FinancialInformation

												WHERE 
													InformationType = 'Lifetime Comprehensive Giving'
												AND InformationSource = 'OSU Foundation'
												AND Value > 0
											) AS Donor ON C.ConstituentDimID = Donor.ConstituentDimID 
WHERE
	PCC.ConstituentCode = 'Friend'
AND Donor.ConstituentDimID IS NULL

UNION
-- Solicit Codes Excludes
SELECT 
    ConstituentDimID
           
FROM 
	dbo.DIM_ConstituentAttribute
           
WHERE 
	AttributeCategory = 'Solicit Code'	
AND AttributeDescription IN 
							(
								'MF - No OSUF Postal Mail'
							, 'MFS - No OSUF Postal Mail Solicitation'
							, 'X - Permanent No Contact'
							, 'X3 - No Contact'
							, 'XF - Permanent No Contact from OSUF'
							, 'XF3 - No Contact from OSUF'
							, 'XSF - Permanent No Solicitation from OSUF'
							, 'SF - No Solicitation'
							, 'SF1 - No OSUF Solicitation (1yr)'
							)



UNION
SELECT 
	C.ConstituentDimID

FROM
	dbo.DIM_Constituent AS C 
										 
WHERE
	C.ConstituentID IS NOT NULL
AND C.ConstituentDimID <> -1

AND CASE
			--Just incase these records, somehow pop in the list, they are going to be removed
			WHEN C.ConstituentDimID IN (SELECT DISTINCT ConstituentDimID FROM dbo.DIM_ConstituentConstitCode WHERE ConstituentCode IN ('On Hold New Record', 'OSUAA Legacy', 'Utility Record') ) THEN 'Exclude'
					  
			/* Standard Constituent Omissions */
			WHEN C.IsAConstituent='No'                                                            THEN 'Exclude'
			WHEN C.IsDeceased = 'Yes'                                                             THEN 'Exclude'
			WHEN C.NoValidAddress = 'Yes'                                                         THEN 'Exclude'
			WHEN C.IsInactive='Yes'                                                               THEN 'Exclude'

			WHEN C.KeyIndicator = 'O'                                                             THEN 'Exclude'

			/* Address Omissions */ 
			WHEN C.SendMail='No'                                                                  THEN 'Exclude'             
			WHEN COALESCE(C.Country, '') NOT IN ('', 'United States')                             THEN 'Exclude'   -- International Address
			WHEN COALESCE(C.State, '')  Not In(Select [State] From dbo.DIM_OSUF_USStateDescriptions)  THEN 'Exclude'   -- International Address
			WHEN C.Address1 IS NULL                                                               THEN 'Exclude'
			WHEN COALESCE(C.Address1, '') = ''                                                    THEN 'Exclude'
			WHEN COALESCE(C.City, '') = ''                                                        THEN 'Exclude'
			WHEN COALESCE(C.State, '') = ''                                                       THEN 'Exclude'
			WHEN COALESCE(C.PostCode, '') = ''                                                    THEN 'Exclude'

			/* Dublicate, Anonymous, Unkown, and other Record Anomoly Omissions */
			WHEN C.Address1 LIKE 'Duplicate see #%'                                               THEN 'Exclude'
			WHEN C.Address1 LIKE 'See Duplicate #%'                                               THEN 'Exclude'
			WHEN C.FullName LIKE '%Anon%#%'                                                       THEN 'Exclude'
			WHEN C.FullName LIKE 'ID%Unknown'                                                     THEN 'Exclude'

			ELSE 'Include'
	END = 'Exclude'




/*============================================================================================

--Description: Includelist_minus_Excludelist table 

============================================================================================*/
--Delete the #temp table if it exists
IF OBJECT_ID('tempdb..#IncludeList_minus_Excludelist') IS NOT NULL
  DROP TABLE          #IncludeList_minus_Excludelist
GO

CREATE TABLE #IncludeList_minus_Excludelist
	                                        (
												ConstituentDimID INT NOT NULL PRIMARY KEY CLUSTERED
											)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #IncludeList_minus_ExcludeList', 0, 1, 56) WITH NOWAIT
INSERT INTO            #Includelist_minus_Excludelist
SELECT 
  C.ConstituentDimID

FROM
  dbo.DIM_Constituent AS C
						     INNER JOIN 
											   (
													SELECT 
								           			  ConstituentDimID 
								           	
													FROM
								           			  #IncludeList 
								            
													UNION
													SELECT 
								           			  SPC.ConstituentDimID 
								           	
													FROM
								           			  #IncludeList AS E
																		INNER JOIN dbo.DIM_Constituent C ON E.ConstituentDimID = C.ConstituentDimID
																		INNER JOIN dbo.DIM_Constituent SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
													
													WHERE
													    SPC.ConstituentID IS NOT NULL
											   ) AS IL ON C.ConstituentDimID = IL.ConstituentDimID							
                           
							--Exclusion list
							 LEFT OUTER JOIN 
											   (
													SELECT 
								           			  ConstituentDimID 
								           	
													FROM
								           			  #Excludelist 
								            
													UNION
													SELECT 
								           			  SPC.ConstituentDimID 
								           	
													FROM
								           			  #Excludelist AS E
																		INNER JOIN dbo.DIM_Constituent C ON E.ConstituentDimID = C.ConstituentDimID
																		INNER JOIN dbo.DIM_Constituent SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
													
													WHERE
													    SPC.ConstituentID IS NOT NULL
											   ) AS EL ON C.ConstituentDimID = EL.ConstituentDimID
                           
WHERE
    C.ConstituentID IS NOT NULL
AND C.ConstituentDimID <> -1
AND C.ConstituentSystemID = C.HouseholdSystemID --Household the list
AND EL.ConstituentDimID IS NULL

/*============================================================================================
--
--Primary Education Information
--
============================================================================================*/

--Delete the #temp table if it exists
IF OBJECT_ID('tempdb..#Education') IS NOT NULL
    DROP TABLE        #Education
GO

--Create the #temp table
CREATE TABLE #Education 
						(
							 ConstituentDimID INT NOT NULL PRIMARY KEY CLUSTERED
						   , Major            VARCHAR(100)
						   , DateGraduated    DATETIME
						   , Department       VARCHAR(100)
						   , SchoolName       VARCHAR(100)
						   , SchoolType       VARCHAR(100) NOT NULL
						   , SchoolTypeTrans  VARCHAR(100)
						)


RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #Education', 0, 1, 56) WITH NOWAIT
INSERT INTO            #Education
SELECT 
  E.ConstituentDimID
, M.MajorCode AS Major

--Convert FuzzyDateGraduated into Datetime
, CAST(CASE 
			WHEN LEN(E.FuzzyDateGraduated) = 4 THEN LEFT(E.FuzzyDateGraduated, 4) + '-05-01 00:00:00.000'
			WHEN LEN(E.FuzzyDateGraduated) = 6 THEN LEFT(E.FuzzyDateGraduated, 4) + '-' + RIGHT(E.FuzzyDateGraduated, 2) + '-01 00:00:00.000' 
			WHEN LEN(E.FuzzyDateGraduated) = 8 THEN LEFT(E.FuzzyDateGraduated, 4) + '-' + RIGHT(LEFT(E.FuzzyDateGraduated, 6), 2) + '-' + RIGHT(E.FuzzyDateGraduated, 2) + ' 00:00:00.000' 
			WHEN E.ClassYear IS NOT NULL THEN LEFT(CAST(E.ClassYear AS VARCHAR(6)), 4) + '-05-01 00:00:00.000'
		END AS DATETIME) AS  DateGraduated
				
, Department.Department AS Department
, E.SchoolName
, CASE
		WHEN Tul.ConstituentDimID IS NOT NULL THEN 'OSU-Tulsa'
		WHEN E.SchoolType = 'Center For Health Sciences - Grad' THEN 'OSU-Center for Health Sciences'
		ELSE E.SchoolType
  END AS SchoolType

, NULL AS SchoolTypeTrans

FROM 
	dbo.DIM_ConstituentEducation AS E 
				                    INNER JOIN dbo.DIM_Constituent AS C ON E.ConstituentDimID = C.ConstituentDimID
												 
									--Major with code to pick only one Major
									LEFT OUTER JOIN
													(
														SELECT
														  ConstituentDimID
														, ConstituentEducationDimID
														, MajorCode

														FROM
															(
																SELECT
																  ConstituentDimID
																, ConstituentEducationDimID
																, MajorCode
																, ROW_NUMBER() OVER (PARTITION BY ConstituentDimID, ConstituentEducationDimID ORDER BY Sequence ASC ) AS Seq
																			
																FROM 
																	dbo.DIM_ConstituentEducationMajor
															) AS Q

														WHERE
															Seq = 1
													) AS M ON E.ConstituentDimID = M.ConstituentDimID AND E.ConstituentEducationDimID = M.ConstituentEducationDimID
												 
									--Department with code to pick only one Department
									LEFT OUTER JOIN
													(
														SELECT 
														  ConstituentDimID
														, ConstituentEducationDimID
														, AttributeDescription AS Department

														FROM
															(
																SELECT 
																	ConstituentDimID
																, ConstituentEducationDimID
																, AttributeDescription
																, ROW_NUMBER() OVER (PARTITION BY ConstituentDimID, ConstituentEducationDimID ORDER BY Sequence ASC ) AS Seq

																FROM 
																	dbo.DIM_ConstituentEducationAttribute
																	
																WHERE 
																	AttributeCategory = 'Degree Department'
															) AS Q

														WHERE
															Seq = 1
													) AS Department ON E.ConstituentDimID = Department.ConstituentDimID AND E.ConstituentEducationDimID = Department.ConstituentEducationDimID
    
									--OSU Tulsa sub query
									LEFT OUTER JOIN
												(
													SELECT DISTINCT 
													  ConstituentDimID
													, ConstituentEducationDimID
													
													FROM 
													  dbo.DIM_ConstituentEducationAttribute
													
													WHERE 
													    AttributeCategory = 'Degree OSU-Tulsa Commencement Participant'
													AND AttributeDescription = 'Yes'
												) AS Tul ON E.ConstituentDimID = Tul.ConstituentDimID AND E.ConstituentEducationDimID = Tul.ConstituentEducationDimID

WHERE 
	E.SchoolName IN ('Oklahoma State University', 'OSU-Oklahoma City', 'OSU-Center for Health Sciences', 'OSU-Institute of Technology' )
AND E.IsPrimary = 'Yes'
AND E.SchoolType <> 'Unknown'
AND C.IsDeceased = 'No'


RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating column SchoolTypeTrans', 0, 1, 56) WITH NOWAIT
--Translate the SchoolType field to be what is in the table MikesTest.dbo.[04292015_StatementMailerDegreeDepartmentFunds]
UPDATE E
SET SchoolTypeTrans = CASE
						WHEN E.SchoolType = 'CEAT'                           THEN 'CEAT'
                        WHEN E.SchoolType = 'SSB'                            THEN 'Business'
						WHEN E.SchoolType = 'A&S'                            THEN 'Arts and Sciences'
						WHEN E.SchoolType = 'CASNR'                          THEN 'DASNR'
						WHEN E.SchoolType = 'COHS'                           THEN 'Human Sciences'
						WHEN E.SchoolType = 'OSU-Oklahoma City'              THEN 'OSU-OKC'
						WHEN E.SchoolType = 'OSU-Institute of Technology'    THEN 'OSU-Institute of Technology'
						WHEN E.SchoolType = 'COE'                            THEN 'College of Education'
						WHEN E.SchoolType = 'OSU-Tulsa'                      THEN 'OSU-Tulsa'
						WHEN E.SchoolType = 'CVHS'                           THEN 'CVHS'
						WHEN E.SchoolType = 'OSU-Center for Health Sciences' THEN 'OSUCHS'
						WHEN E.SchoolType = 'Graduate College'               THEN 'Graduate College'
						WHEN E.SchoolType = 'SIS'                            THEN 'SIS (School of International Studies)'
						ELSE SchoolType 
				  END

FROM #Education AS E





/*============================================================================================
--
--Description: Phone Information
--
============================================================================================*/

--Delete the #Phones table if it exists
IF OBJECT_ID('tempdb..#Phones') IS NOT NULL
    DROP TABLE        #Phones
GO

CREATE TABLE #Phones
						  (
							   ConstituentDimID INT NOT NULL PRIMARY KEY CLUSTERED
							 , HomePhone        VARCHAR(100)
							 , HomeCell         VARCHAR(100)
						  )



RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #Phones', 0, 1, 56) WITH NOWAIT
INSERT INTO            #Phones	
SELECT
  C.ConstituentDimID
, HomePhone.PhoneNumber AS HomePhone
, HomeCell.PhoneNumber  AS HomeCell

FROM
  dbo.DIM_Constituent AS C 
							LEFT OUTER JOIN
												(
												   SELECT 
													 ConstituentDimID
												   , PhoneNumber
												   , PhoneType  
											       
												   FROM
														(
														   SELECT 
															 ConstituentDimID
														   , PhoneNumber
														   , PhoneType  
														   --, Rank
														   , ROW_NUMBER() OVER( PARTITION BY ConstituentDimID ORDER BY Rank ASC) AS Seq
													       
														   FROM
																(
																   SELECT 
																	 CA.ConstituentDimID
																   , CP.PhoneNumber
																   , CP.PhoneType
															          
																   , CASE
																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home' AND CA.Preferred = 'Yes'		THEN 2.0
																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home'								THEN 2.1

																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Phone' AND CA.Preferred = 'Yes'		THEN 3.0
																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Phone'								THEN 3.1

																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home 2' AND CA.Preferred = 'Yes'	THEN 4.0
																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home 2'								THEN 4.1

																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home 3' AND CA.Preferred = 'Yes'	THEN 5.0
																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home 3'								THEN 5.1

																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home 4' AND CA.Preferred = 'Yes'	THEN 6.0
																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home 4'								THEN 6.1

																		   
																		   WHEN CP.PhoneType = 'Local Phone'							THEN 115.00
																		   WHEN CP.PhoneType = 'AlumniSync Phone'						THEN 115.01
																		   WHEN CP.PhoneType = 'AlumniSync Phone 2'						THEN 115.02
																		   WHEN CP.PhoneType = 'AlumniSync Phone 3'					    THEN 115.03
																		   
																		   WHEN CP.PhoneType = 'PhoneFinder'							THEN 116.00           
																		   WHEN CP.PhoneType = 'PhoneFinder2'							THEN 116.01
																		   WHEN CP.PhoneType = 'PhoneFinder3'							THEN 116.02
																		   WHEN CP.PhoneType = 'PhoneFinder4'							THEN 116.03
																		   WHEN CP.PhoneType = 'PhoneFinder5'							THEN 116.04
																		   WHEN CP.PhoneType = 'PhoneFinder6'							THEN 116.05
																		   WHEN CP.PhoneType = 'PhoneFinder7'							THEN 116.06
																		   WHEN CP.PhoneType = 'PhoneFinder8'							THEN 116.07
																		   WHEN CP.PhoneType = 'PhoneFinder9'							THEN 116.08
																		   WHEN CP.PhoneType = 'PhoneFinder10'							THEN 116.09
																		   WHEN CP.PhoneType = 'PhoneFinder11'							THEN 116.10
																		   WHEN CP.PhoneType = 'PhoneFinder12'							THEN 116.11
																		   WHEN CP.PhoneType = 'PhoneFinder13'							THEN 116.12
																		   WHEN CP.PhoneType = 'PhoneFinder14'							THEN 116.13
																		   WHEN CP.PhoneType = 'PhoneFinder15'							THEN 116.14
																		   WHEN CP.PhoneType = 'PhoneFinder16'							THEN 116.15
																		   WHEN CP.PhoneType = 'PhoneFinder17'							THEN 116.16
																		   WHEN CP.PhoneType = 'PhoneFinder18'							THEN 116.17
																		   WHEN CP.PhoneType = 'PhoneFinder19'							THEN 116.18
																		   WHEN CP.PhoneType = 'PhoneFinder20'							THEN 116.19

																		   ELSE 9999.0
																	 END AS Rank

																   FROM 
																	 dbo.DIM_ConstituentAddress AS CA  
																													INNER JOIN dbo.DIM_ConstituentPhone AS CP   ON (    CP.ConstituentDimID = CA.ConstituentDimID AND CP.ConstituentAddressSystemID = CA.ConstituentAddressSystemID   )
																                                    
																   WHERE
																	  CP.PhoneType NOT LIKE '%Email%'  
																   AND CP.PhoneType NOT LIKE '%WebSite%'
																   AND CP.PhoneType NOT LIKE '%Facebook%'
																   AND CP.PhoneType NOT LIKE '%LinkedIn%'
																   AND CP.PhoneType NOT LIKE '%Pager%'
																   AND CP.PhoneType NOT LIKE '%Foreign%'
																   AND CP.PhoneType NOT LIKE '%Twitter%'
																   AND CP.PhoneType NOT LIKE '%My Space%'
																   AND CP.PhoneType NOT LIKE '%MySpace%'
																   AND CP.PhoneType NOT LIKE '%Fax%'

																	 -- Unwanted Phone Numbers
																   AND CP.PhoneNumber NOT LIKE  '%@%'
																   AND CP.PhoneNumber NOT LIKE '%00000000%'
																   AND CP.PhoneNumber NOT LIKE '%Print%'
																   AND CP.PhoneNumber NOT LIKE '%www%'
																   AND CP.PhoneNumber NOT LIKE '%http%'
																   AND CP.PhoneNumber NOT LIKE '%.com%'

																   AND LEN(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CP.PhoneNumber, ' ', ''), '(', ''), ')', ''), '-', ''), '.', '')) >= 7 
																   AND CA.AddressType = 'Home'
																   AND ( CP.PhoneType LIKE 'Home%' OR CP.PhoneType LIKE 'Phone%' )
																) AS QInner
														   WHERE
															   Rank <> 9999.0

														) AS QOuter
														       			
												   WHERE
													   Seq = 1 
											                                              
												 ) AS HomePhone	ON C.ConstituentDimID = HomePhone.ConstituentDimID						

							LEFT OUTER JOIN
												(

												   SELECT 
													 ConstituentDimID
												   , PhoneNumber
												   , PhoneType  
											       
												   FROM
														(
														   SELECT 
															 ConstituentDimID
														   , PhoneNumber
														   , PhoneType   
														   --, Rank
														   , ROW_NUMBER() OVER( PARTITION BY ConstituentDimID ORDER BY Rank ASC) AS Seq
													       
														   FROM
																(
																   SELECT 
																	 CA.ConstituentDimID
																   , CP.PhoneNumber
																   , CP.PhoneType
															          
																   , CASE
																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home Cell' AND CA.Preferred = 'Yes'		THEN 2.0 
																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home Cell'								THEN 2.1

																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home Cell 2' AND CA.Preferred = 'Yes'	THEN 3.0                          
																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home Cell 2'							THEN 3.1 

																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home Cell 3' AND CA.Preferred = 'Yes'	THEN 4.0
																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home Cell 3'							THEN 4.1

																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home Cell 4' AND CA.Preferred = 'Yes'	THEN 5.0
																		   WHEN CA.AddressType = 'Home' AND CP.PhoneType = 'Home Cell 4'							THEN 5.1

																		   WHEN CP.PhoneType = 'AlumniSync Cell'							THEN 115.00
																		   WHEN CP.PhoneType = 'AlumniSync Cell 2'							THEN 115.01
																		   WHEN CP.PhoneType = 'AlumniSync Cell 3'							THEN 115.02
																		   WHEN CP.PhoneType = 'AlumniSync Cell 4'							THEN 115.03


																		   ELSE 9999.0
																	 END AS Rank

																   FROM 
																	 dbo.DIM_ConstituentAddress AS CA  
																													INNER JOIN dbo.DIM_ConstituentPhone AS CP  ON (    CP.ConstituentDimID = CA.ConstituentDimID AND CP.ConstituentAddressSystemID = CA.ConstituentAddressSystemID   )
																                                    
																   WHERE
																       CP.PhoneType NOT LIKE '%Email%'  
																   AND CP.PhoneType NOT LIKE '%WebSite%'
																   AND CP.PhoneType NOT LIKE '%Facebook%'
																   AND CP.PhoneType NOT LIKE '%LinkedIn%'
																   AND CP.PhoneType NOT LIKE '%Pager%'
																   AND CP.PhoneType NOT LIKE '%Foreign%'
																   AND CP.PhoneType NOT LIKE '%Twitter%'
																   AND CP.PhoneType NOT LIKE '%My Space%'
																   AND CP.PhoneType NOT LIKE '%MySpace%'
																   AND CP.PhoneType NOT LIKE '%Fax%'

																	 -- Unwanted Phone Numbers
																   AND CP.PhoneNumber NOT LIKE  '%@%'
																   AND CP.PhoneNumber NOT LIKE '%00000000%'
																   AND CP.PhoneNumber NOT LIKE '%Print%'
																   AND CP.PhoneNumber NOT LIKE '%www%'
																   AND CP.PhoneNumber NOT LIKE '%http%'
																   AND CP.PhoneNumber NOT LIKE '%.com%'

																   AND LEN(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CP.PhoneNumber, ' ', ''), '(', ''), ')', ''), '-', ''), '.', '')) >= 7 
																   AND CA.AddressType = 'Home'
																   AND CP.PhoneType LIKE 'Home Cell%'
																   
																) AS QInner
														   WHERE
															   Rank <> 9999.0

														) AS QOuter
														       			
												   WHERE
													   Seq = 1 
											                                              
												 ) AS HomeCell	ON C.ConstituentDimID = HomeCell.ConstituentDimID								

WHERE
    C.ConstituentID IS NOT NULL
AND C.ConstituentDimID <> -1
AND C.KeyIndicator = 'I'
AND C.IsDeceased = 'No'
AND C.IsInactive = 'No'

--Delete rows where both phone numbers are blank.
DELETE FROM #Phones
WHERE HomePhone IS NULL AND HomeCell IS NULL





/*============================================================================================
--
--Description: FY16 Donor Type 
--
============================================================================================*/

--Delete the #temp table if it exists
IF OBJECT_ID('tempdb..#DonorType') IS NOT NULL
    DROP TABLE        #DonorType
GO

CREATE TABLE #DonorType
						(
							  ConstituentDimID    INT NOT NULL PRIMARY KEY CLUSTERED
							, DPAGDonorTypeBucket VARCHAR(50) NOT NULL
							, FiscalYear          INT
						)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #DonorType', 0, 1, 56) WITH NOWAIT
INSERT INTO            #DonorType
SELECT
  C.ConstituentDimID
, DT.DPAGDonorTypeBucket
, DT.FiscalYear

FROM 
  dbo.OSUF_DonorType AS DT
							INNER JOIN dbo.DIM_Constituent C ON DT.ConstituentSystemID = C.ConstituentSystemID

WHERE
    C.KeyIndicator = 'I'
AND C.IsDeceased = 'No'
AND C.IsInactive = 'No'
AND DT.FiscalYear = 2017




/*============================================================================================
--
--FY16 Projected Gifts that tied to a commitment from FY15 or older
--
============================================================================================*/

--Delete the #temp table if it exists
IF OBJECT_ID('tempdb..#FY16ProjectGifts') IS NOT NULL
    DROP TABLE        #FY16ProjectGifts
GO

CREATE TABLE #FY16ProjectGifts
								(
									  CGFactID         INT          NOT NULL PRIMARY KEY CLUSTERED
									, GiftFactID       INT          NOT NULL
									, ConstituentDimID INT          NOT NULL
									, Amount           MONEY        NOT NULL
									, Fund             VARCHAR(20)  NOT NULL
									, GiftFiscalYear   INT          NOT NULL
									, GiftType         VARCHAR(100) NOT NULL
									, GiftDate         DATETIME     NOT NULL
									, IsAGGift         VARCHAR(3)   NOT NULL
									, AppealIdentifier VARCHAR(20)
									, REGiftType       VARCHAR(50)  NOT NULL
								)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #FY16ProjectGifts', 0, 1, 56) WITH NOWAIT
INSERT INTO            #FY16ProjectGifts
SELECT
  -1 * AP.CAPDimID AS CGFactID
, -1 * AP.CAPDimID AS GiftFactID  --This are projected gifts, no GiftFactID so we are using a fake one.
, C.ConstituentDimID
, AP.GiftAmount AS Amount
, AP.FundIdentifier AS Fund
, AP.FiscalYear AS GiftFiscalYear
, 'Annual Projection' AS GiftType
, AP.GiftDate
, AP.IsAGGift
, AP.AppealIdentifier
, 'Annual Projection' AS REGiftType 

FROM 
	[Report_DW].[dbo].[OSUF_Comprehensive_Annual_Projection] AS AP
																INNER JOIN dbo.DIM_Constituent AS C ON AP.ConstituentID = C.ConstituentID

WHERE 
	AP.GiftAmount > 0
AND AP.GiftCommitmentDate < '2015-07-01 00:00:00.000'
ANd AP.GiftFactID IS NULL
AND AP.FiscalYear = 2016
AND C.IsDeceased = 'No'
AND C.IsInactive = 'No'

/*============================================================================================
--
--Description: Annual Giving Funds
--                    
==============================================================================================*/


--Delete the #table if it exists
IF OBJECT_ID('tempdb..#AGFunds') IS NOT NULL
    DROP TABLE        #AGFunds
GO

CREATE TABLE #AGFunds
						(
							  FundDimID           INT          NOT NULL PRIMARY KEY CLUSTERED
							, FundIdentifier      VARCHAR(25)  NOT NULL
						)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #AGFunds', 0, 1, 56) WITH NOWAIT
INSERT INTO #AGFunds
SELECT
  F.FundDimID
, F.FundIdentifier

FROM
  dbo.DIM_Fund AS F
					INNER JOIN dbo.OSUF_CampusCall_SolicitableFunds AS AG ON F.FundIdentifier = AG.Designation



/*======================================================================================================================
--
--Description: Gifts - Development Production, Recognition Credit, OSUAA Membership Dues
--                    
========================================================================================================================*/

--Delete the #table if it exists
IF OBJECT_ID('tempdb..#ProductionGifts') IS NOT NULL
    DROP TABLE        #ProductionGifts
GO

CREATE TABLE #ProductionGifts
										(
											OCPRDimID           INT          NOT NULL PRIMARY KEY CLUSTERED
										  , ConstituentDimID    INT          NOT NULL
										  , GiftType            VARCHAR(100) NOT NULL
										  , FundIdentifier      VARCHAR(20)  NOT NULL
										  , FundIdentifierTrans VARCHAR(20)  NOT NULL 
										  , Amount	            MONEY        NOT NULL
										  , GiftDate            DATETIME     NOT NULL
										  , FiscalYear          INT          NOT NULL
										  , IsMatchingGift      VARCHAR(3)   NOT NULL
										  , IsAGGift            VARCHAR(3)   NOT NULL
										  , IsInactive          VARCHAR(3)   NOT NULL
										  , AppealIdentifier    VARCHAR(20)  
										  , AppealCampaign      VARCHAR(20) 
										)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #ProductionGifts', 0, 1, 56) WITH NOWAIT
INSERT INTO            #ProductionGifts
SELECT 
  CPR.OCPRDimID
, CPR.ConstituentDimID
, CPR.GiftType
, CPR.FundIdentifier
, CASE
		WHEN AGFunds.FundIdentifier IS NOT NULL THEN AGFunds.FundIdentifier
		WHEN FundTrans.FundIdentifier IS NOT NULL THEN FundTrans.SuggestedFundIdentifier
		ELSE CPR.FundIdentifier
	END AS FundIdentifierTrans
, CPR.CGPRAmount AS Amount
, CPR.GiftDate
, CPR.FiscalYear

, CASE 
	   WHEN CPR.GiftType = 'MG Pledge' THEN 'Yes' 
	   WHEN CPR.GiftType = 'Other' AND CPR.GiftSubType = 'Recognition Credit' AND CPR.CGGiftType LIKE '%MatchingGift' THEN 'Yes'
	   ELSE 'No' 
  END AS IsMatchingGift
, CPR.IsAGGift
, F.IsInactive
, A.AppealIdentifier
, A.CampaignIdentifier AS AppealCampaign

FROM 
  Report_DW.dbo.OSUF_Comp_Production_and_Receipts AS CPR
														INNER JOIN dbo.FACT_Gift AS G ON CPR.GiftFactID = G.GiftFactID
														INNER JOIN dbo.DIM_Fund  AS F ON G.FundDimID = F.FundDimID
														LEFT OUTER JOIN dbo.DIM_Appeal AS A ON G.AppealDimID = A.AppealDimID

														LEFT OUTER JOIN #AGFunds AS AGFunds ON CPR.FundIdentifier = AGFunds.FundIdentifier
														LEFT OUTER JOIN MikesTest.[dbo].[FY16StatementMailerFundTranslation] AS FundTrans ON CPR.FundIdentifier = FundTrans.[FundIdentifier]
																												
WHERE 	
    (
		  (CPR.DataSource = 'Development' AND CPR.Measure = 'Production')
		OR CPR.DataSource IN ('OSUAA Membership Dues', 'Recognition Credit')
	)
AND CPR.KeyIndicator = 'I'
AND CPR.IsDeceased = 'No'

AND CPR.CGPRAmount > 0


/*============================================================================================
--
--Description: Fund Array - Annual Giving defined fund with most recently
--                    
==============================================================================================*/

--Delete the #table if it exists
IF OBJECT_ID('tempdb..#FundsGiventoMostRecently') IS NOT NULL
    DROP TABLE        #FundsGiventoMostRecently
GO

CREATE TABLE #FundsGiventoMostRecently
										(
											  PKID                INT          NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
											, ConstituentDimID    INT          NOT NULL
											, FundIdentifierTrans VARCHAR(20)  NOT NULL
											, GiftDate            DATETIME     NOT NULL 
											, Seq                 INT          NOT NULL
										)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #FundsGiventoMostRecently', 0, 1, 56) WITH NOWAIT
INSERT INTO            #FundsGiventoMostRecently
SELECT
  QL1.ConstituentDimID
, QL1.FundIdentifierTrans
, QL1.GiftDate
, ROW_NUMBER() OVER (PARTITION BY QL1.ConstituentDimID ORDER BY QL1.GiftDate DESC, QL1.FundIdentifierTrans ASC  ) AS Seq

FROM
	(
		SELECT
		  ConstituentDimID
		, FundIdentifierTrans
		, MAX(GiftDate) AS GiftDate

		FROM
		  #ProductionGifts

		WHERE
		    IsMatchingGift = 'No'

		GROUP BY
		  ConstituentDimID
		, FundIdentifierTrans
	) AS QL1
				INNER JOIN dbo.DIM_Fund AS F ON QL1.FundIdentifierTrans = F.FundIdentifier

--WHERE
--	F.IsInactive = 'No'



/*============================================================================================
--
--Description: Fund Array - Annual Giving defined fund with most total amount given
--                    
==============================================================================================*/

--Delete the #table if it exists
IF OBJECT_ID('tempdb..#FundsGiventoMostMoney') IS NOT NULL
    DROP TABLE        #FundsGiventoMostMoney
GO

CREATE TABLE #FundsGiventoMostMoney
										(
											  PKID                INT          NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
											, ConstituentDimID    INT          NOT NULL
											, FundIdentifierTrans VARCHAR(20)  NOT NULL
											, Amount              MONEY        NOT NULL 
											, Seq                 INT          NOT NULL
										)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #FundsGiventoMostMoney', 0, 1, 56) WITH NOWAIT
INSERT INTO            #FundsGiventoMostMoney
SELECT
  QL1.ConstituentDimID
, QL1.FundIdentifierTrans
, QL1.Amount
, ROW_NUMBER() OVER (PARTITION BY QL1.ConstituentDimID ORDER BY QL1.Amount DESC, QL1.FundIdentifierTrans ASC  ) AS Seq

FROM
	(
		SELECT
		  ConstituentDimID
		, FundIdentifierTrans
		, SUM(Amount) AS Amount

		FROM
		  #ProductionGifts

		WHERE
		    IsMatchingGift = 'No'

		GROUP BY
		  ConstituentDimID
		, FundIdentifierTrans
	) AS QL1
				INNER JOIN dbo.DIM_Fund AS F ON QL1.FundIdentifierTrans = F.FundIdentifier

--WHERE
--	F.IsInactive = 'No'




/*============================================================================================
--
--Description: Fund Array - Annual Giving defined fund with most frerquently
--                    
==============================================================================================*/

--Delete the #table if it exists
IF OBJECT_ID('tempdb..#FundsGiventoMostFrequently') IS NOT NULL
    DROP TABLE #FundsGiventoMostFrequently
GO

CREATE TABLE #FundsGiventoMostFrequently
										(
											  PKID                INT          NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
											, ConstituentDimID    INT          NOT NULL
											, FundIdentifierTrans VARCHAR(20)  NOT NULL
											, GiftDate            DATETIME     NOT NULL 
											, Seq                 INT          NOT NULL
										)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #FundsGiventoMostFrequently', 0, 1, 56) WITH NOWAIT
INSERT INTO            #FundsGiventoMostFrequently
SELECT
  QL1.ConstituentDimID
, QL1.FundIdentifierTrans
, QL1.theCount
, ROW_NUMBER() OVER (PARTITION BY QL1.ConstituentDimID ORDER BY QL1.theCount DESC, QL1.FundIdentifierTrans ASC  ) AS Seq

FROM
	(
		SELECT
		  ConstituentDimID
		, FundIdentifierTrans
		, COUNT(1) AS theCount

		FROM
		  #ProductionGifts

		WHERE
		    IsMatchingGift = 'No'

		GROUP BY
		  ConstituentDimID
		, FundIdentifierTrans
	) AS QL1
				INNER JOIN dbo.DIM_Fund AS F ON QL1.FundIdentifierTrans = F.FundIdentifier

--WHERE
--	F.IsInactive = 'No'


/*============================================================================================
--
--Description: Fund Array - Test Array Funds
--                    
==============================================================================================*/

--Delete the #table if it exists
IF OBJECT_ID('tempdb..#FundTestArrayFunds') IS NOT NULL
    DROP TABLE        #FundTestArrayFunds
GO

CREATE TABLE #FundTestArrayFunds
										(
											  PKID                INT          NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
											, ConstituentDimID    INT          NOT NULL
											, FundIdentifierTrans VARCHAR(20)  NOT NULL
											, TotalPoints         INT          NOT NULL 
											, Seq                 INT          NOT NULL
										)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #FundArraypoints', 0, 1, 56) WITH NOWAIT
INSERT INTO #FundTestArrayFunds

SELECT
  QL3.ConstituentDimID	
, QL3.FundIdentifierTrans
, QL3.TotalPoints
, ROW_NUMBER() OVER (PARTITION BY QL3.ConstituentDimID ORDER BY QL3.TotalPoints DESC, QL3.FundIdentifierTrans ASC  ) AS Seq

FROM
	(
		SELECT
		  QL2.ConstituentDimID
		, QL2.FundIdentifierTrans
		, QL2.TotalPoints TotalPoints 

		FROM
			(
				SELECT
				  QL1.ConstituentDimID
				, QL1.FundIdentifierTrans
				, SUM(QL1.Points) AS TotalPoints

				FROM
					(
						SELECT
						  MR.ConstituentDimID
						, MR.FundIdentifierTrans
						, CASE
								WHEN MR.Seq = 1 THEN 4
								WHEN MR.Seq = 2 THEN 3
								WHEN MR.Seq = 3 THEN 2
								WHEN MR.Seq = 4 THEN 1
						  END AS Points

						FROM 
						  #FundsGiventoMostRecently AS MR

						WHERE
							MR.Seq <= 4

						
						UNION ALL
						SELECT
						  MR.ConstituentDimID
						, MR.FundIdentifierTrans
						, CASE
								WHEN MR.Seq = 1 THEN 4
								WHEN MR.Seq = 2 THEN 3
								WHEN MR.Seq = 3 THEN 2
								WHEN MR.Seq = 4 THEN 1
						  END AS Points

						FROM 
						  #FundsGiventoMostFrequently AS MR

						WHERE
							MR.Seq <= 4


						UNION ALL
						SELECT
						  MR.ConstituentDimID
						, MR.FundIdentifierTrans
						, CASE
								WHEN MR.Seq = 1 THEN 4
								WHEN MR.Seq = 2 THEN 3
								WHEN MR.Seq = 3 THEN 2
								WHEN MR.Seq = 4 THEN 1
						  END AS Points

						FROM 
						  #FundsGiventoMostMoney AS MR

						WHERE
							MR.Seq <= 4
					) AS QL1

				GROUP BY
				  QL1.ConstituentDimID
				, QL1.FundIdentifierTrans
		) AS QL2
				--LEFT OUTER JOIN
				--				(
				--					SELECT DISTINCT
				--					  MR.ConstituentDimID
				--					, MR.FundIdentifierTrans

				--					FROM 
				--					  #ProductionGifts AS MR

				--					WHERE
				--						MR.AppealCampaign IN 
				--											(
				--												  'ANNGIVING'
				--												, 'AG2013'
				--												, 'AG2014'
				--												, 'AG2015'
				--												, 'AG2016'
				--											)
				--				) AS BonusPoints ON QL2.ConstituentDimID = BonusPoints.ConstituentDimID AND QL2.FundIdentifierTrans = BonusPoints.FundIdentifierTrans
	) AS QL3


	
/*============================================================================================
--
--Description: Fund Array items that apply to Normal Fund Array and Test fund Array
--
============================================================================================*/

--Delete the #table if it exists
IF OBJECT_ID('tempdb..#DesignationDataBoth') IS NOT NULL
    DROP TABLE        #DesignationDataBoth
GO

--Create the #temp table
CREATE TABLE #DesignationDataBoth
							   (
									  PKID              INT          NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
									, ConstituentDimID  VARCHAR(20)  NOT NULL
									, FundIdentifier    VARCHAR(20)  NOT NULL
									, DesignationsOrder INT          NOT NULL
									, DataSource        VARCHAR(100) NOT NULL
							   )

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #DesignationDataBoth', 0, 1, 56) WITH NOWAIT
INSERT INTO            #DesignationDataBoth
SELECT
  Q.ConstituentDimID
, Q.FundIdentifier
, Q.DesignationsOrder
, Q.DataSource

FROM
    (
--Begin: Constituent Department fund 1
	   SELECT 
		 E.ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , 100 AS DesignationsOrder
	   , 'Const Pri Degree Dept Fund1 (Blank Majors column)' AS DataSource

	   FROM 
		 #Education AS E
						INNER JOIN MikesTest.[dbo].[01222016_AcademicMailerDegreeDepartmentFunds] AS DDF ON E.SchoolTypeTrans = DDF.College AND E.Department = DDF.DegreeDepartment
						INNER JOIN dbo.DIM_Fund AS F ON DDF.FundID1 = F.FundIdentifier
							
	   WHERE 
	       COALESCE(DDF.DegreeDepartment, '') <> ''
	   AND COALESCE(DDF.[Degree Major Description], '') = ''
--End: Constituent Department fund 1



--Begin: Spouse Department fund 1
UNION ALL
	   SELECT 
		 SPC.ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , 101 AS DesignationsOrder
	   , 'Spouse Const Pri Degree Dept Fund1 (Blank Majors column)' AS DataSource

	   FROM 
		 #Education AS E
						INNER JOIN MikesTest.[dbo].[01222016_AcademicMailerDegreeDepartmentFunds] AS DDF ON E.SchoolTypeTrans = DDF.College AND E.Department = DDF.DegreeDepartment
						INNER JOIN dbo.DIM_Fund        AS F   ON DDF.FundID1 = F.FundIdentifier
						INNER JOIN dbo.DIM_Constituent AS C   ON E.ConstituentDimID = C.ConstituentDimID
						INNER JOIN dbo.DIM_Constituent AS SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
	   
	   WHERE 
	       LTRIM(RTRIM(COALESCE(DDF.DegreeDepartment, ''))) <> ''
	   AND SPC.ConstituentID IS NOT NULL
--End: Spouse Department fund 1



--Begin: Constituent Department fund 2
UNION ALL
	   SELECT 
		 E.ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , 102 AS DesignationsOrder
	   , 'Const Pri Degree Dept Fund2 (Blank Majors column)' AS DataSource

	   FROM 
		 #Education AS E
						INNER JOIN MikesTest.[dbo].[01222016_AcademicMailerDegreeDepartmentFunds] AS DDF ON E.SchoolTypeTrans = DDF.College AND E.Department = DDF.DegreeDepartment
						INNER JOIN dbo.DIM_Fund AS F ON DDF.FundID2 = F.FundIdentifier
							
	   WHERE 
	       COALESCE(DDF.DegreeDepartment, '') <> ''
	   AND COALESCE(DDF.[Degree Major Description], '') = ''
--End: Constituent Department fund 2



--Begin: Spouse Department fund 2
UNION ALL
	   SELECT 
		 SPC.ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , 103 AS DesignationsOrder
	   , 'Spouse Const Pri Degree Dept Fund2 (Blank Majors column)' AS DataSource

	   FROM 
		 #Education AS E
						INNER JOIN MikesTest.[dbo].[01222016_AcademicMailerDegreeDepartmentFunds] AS DDF ON E.SchoolTypeTrans = DDF.College AND E.Department = DDF.DegreeDepartment
						INNER JOIN dbo.DIM_Fund        AS F   ON DDF.FundID2 = F.FundIdentifier
						INNER JOIN dbo.DIM_Constituent AS C   ON E.ConstituentDimID = C.ConstituentDimID
						INNER JOIN dbo.DIM_Constituent AS SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
	   
	   WHERE 
	       LTRIM(RTRIM(COALESCE(DDF.DegreeDepartment, ''))) <> ''
	   AND SPC.ConstituentID IS NOT NULL
--End: Spouse Department fund 2



--Begin: Constituent College/Campus Fund1
UNION ALL
	   SELECT 
		 E.ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , 104 AS DesignationsOrder
	   , 'Const Pri Degree College Fund1 (Blank Majors column, Blank Dept Column)' AS DataSource

	   FROM 
		 #Education AS E
						INNER JOIN MikesTest.[dbo].[01222016_AcademicMailerDegreeDepartmentFunds] AS DDF ON E.SchoolTypeTrans = DDF.College
						INNER JOIN dbo.DIM_Fund AS F ON DDF.FundID1 = F.FundIdentifier
							
	   WHERE 
	       COALESCE(DDF.DegreeDepartment, '') = ''
	   AND COALESCE(DDF.[Degree Major Description], '') = ''
--End: Constituent College/Campus Fund1



--Begin: Spouse College/Campus Fund1
UNION ALL
	   SELECT 
		 SPC.ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , 105 AS DesignationsOrder
	   , 'Spouse Pri Degree College Fund1 (Blank Majors column, Blank Dept Column)' AS DataSource

	   FROM 
		 #Education AS E
						INNER JOIN MikesTest.[dbo].[01222016_AcademicMailerDegreeDepartmentFunds] DDF ON E.SchoolTypeTrans = DDF.College
						INNER JOIN dbo.DIM_Fund        AS F ON DDF.FundID1 = F.FundIdentifier
						INNER JOIN dbo.DIM_Constituent AS C ON E.ConstituentDimID = C.ConstituentDimID
						INNER JOIN dbo.DIM_Constituent AS SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
	   
	   WHERE 
	       COALESCE(DDF.DegreeDepartment, '') = ''
	   AND COALESCE(DDF.[Degree Major Description], '') = ''
	   AND SPC.ConstituentID IS NOT NULL
--End: Spouse College/Campus Fund1



--Begin: Constituent College/Campus Fund2
UNION ALL
	   SELECT 
		 E.ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , 106 AS DesignationsOrder
	   , 'Const Pri Degree College Fund2 (Blank Majors column, Blank Dept Column)' AS DataSource

	   FROM 
		 #Education AS E
						INNER JOIN MikesTest.[dbo].[01222016_AcademicMailerDegreeDepartmentFunds] AS DDF ON E.SchoolTypeTrans = DDF.College
						INNER JOIN dbo.DIM_Fund AS F ON DDF.FundID2 = F.FundIdentifier
							
	   WHERE 
	       COALESCE(DDF.DegreeDepartment, '') = ''
	   AND COALESCE(DDF.[Degree Major Description], '') = ''
--End: Constituent College/Campus Fund2



--Begin: Spouse College/Campus Fund2
UNION ALL
	   SELECT 
		 SPC.ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , 107 AS DesignationsOrder
	   , 'Spouse Pri Degree College Fund2 (Blank Majors column, Blank Dept Column)' AS DataSource

	   FROM 
		 #Education AS E
						INNER JOIN MikesTest.[dbo].[01222016_AcademicMailerDegreeDepartmentFunds] AS DDF ON E.SchoolTypeTrans = DDF.College
						INNER JOIN dbo.DIM_Fund        AS F ON DDF.FundID2 = F.FundIdentifier
						INNER JOIN dbo.DIM_Constituent AS C ON E.ConstituentDimID = C.ConstituentDimID
						INNER JOIN dbo.DIM_Constituent AS SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
	   
	   WHERE 
	       COALESCE(DDF.DegreeDepartment, '') = ''
	   AND COALESCE(DDF.[Degree Major Description], '') = ''
	   AND SPC.ConstituentID IS NOT NULL
--End: Spouse College/Campus Fund2



--Begin: General Scholarship Fund
UNION ALL
	   SELECT 
		 C.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 108 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '20-24400'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
--End: General Scholarship fund



--Begin: Grad College
UNION ALL
       SELECT
		 Grad.ConstituentDimID
       , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 109 AS DesignationsOrder
	   , 'Grad College' AS DataSource		
	   		
	   FROM
	   	(
			SELECT DISTINCT
			  E.ConstituentDimID

			FROM 
				dbo.DIM_ConstituentEducation E

			WHERE 
				E.SchoolName IN ('Oklahoma State University' )
			AND 
				(
					   E.Degree LIKE '%doc%' 
					OR E.Degree LIKE '%mast%'
	            )
	   	) AS Grad 
	   				CROSS JOIN
	   							(
	   								SELECT
	   								  FundIdentifier
	   								, FundDescription
	   
	   								FROM
	   								  dbo.DIM_Fund
	   
	   								WHERE 
	   									FundIdentifier = '20-94430'
	   							) AS Fund 
--End: Grad College



--Begin: Spouse Grad College
UNION ALL
       SELECT
		 SPC.ConstituentDimID
       , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 109 AS DesignationsOrder
	   , 'Grad College' AS DataSource		
	   		
	   FROM
	   	(
			SELECT DISTINCT
			  E.ConstituentDimID

			FROM 
				dbo.DIM_ConstituentEducation E

			WHERE 
				E.SchoolName IN ('Oklahoma State University' )
			AND 
				(
					   E.Degree LIKE '%doc%' 
					OR E.Degree LIKE '%mast%'
	            )
	   	) AS Grad 
	   				INNER JOIN dbo.DIM_Constituent   C ON Grad.ConstituentDimID = C.ConstituentDimID
					INNER JOIN dbo.DIM_Constituent SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
	   				CROSS JOIN
	   							(
	   								SELECT
	   								  FundIdentifier
	   								, FundDescription
	   
	   								FROM
	   								  dbo.DIM_Fund
	   
	   								WHERE 
	   									FundIdentifier = '20-94430'
	   							) AS Fund 

	   WHERE
	       SPC.ConstituentID IS NOT NULL
--End: Spouse Grad College



--Begin: Honors College
UNION ALL
       SELECT
		 Honors.ConstituentDimID
       , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 110 AS DesignationsOrder
	   , 'Honors College' AS DataSource		
	   		
	   FROM
	   	(
	   		SELECT DISTINCT
	   		  ConstituentDimID
	   
	   		FROM 
	   		  dbo.DIM_ConstituentEducationAttribute
	   																						
	   		WHERE 
	   			AttributeCategory = 'Degree Honors Degree' 
	   		AND AttributeDescription = 'Yes'
	   	) AS Honors 
	   				CROSS JOIN
	   							(
	   								SELECT
	   								  FundIdentifier
	   								, FundDescription
	   
	   								FROM
	   								  dbo.DIM_Fund
	   
	   								WHERE 
	   									FundIdentifier = '20-29300'
	   							) AS Fund 
--End: Honors College



--Begin: Spouse Honors College
UNION ALL
       SELECT
		 SPC.ConstituentDimID
       , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 110 AS DesignationsOrder
	   , 'Honors College' AS DataSource		
	   		
	   FROM
	   	(
	   		SELECT DISTINCT
	   		  ConstituentDimID
	   
	   		FROM 
	   		  dbo.DIM_ConstituentEducationAttribute
	   																						
	   		WHERE 
	   			AttributeCategory = 'Degree Honors Degree' 
	   		AND AttributeDescription = 'Yes'
	   	) AS Honors 
	   				INNER JOIN dbo.DIM_Constituent   C ON Honors.ConstituentDimID = C.ConstituentDimID
					INNER JOIN dbo.DIM_Constituent SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
	   				CROSS JOIN
	   							(
	   								SELECT
	   								  FundIdentifier
	   								, FundDescription
	   
	   								FROM
	   								  dbo.DIM_Fund
	   
	   								WHERE 
	   									FundIdentifier = '20-29300'
	   							) AS Fund 

	   WHERE
	       SPC.ConstituentID IS NOT NULL
--End: Spouse Honors College



--Begin: Homecoming and Student Programming Endowment
UNION ALL
	   SELECT 
		 C.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 111 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '20-90750'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'Oklahoma State University'
--End: Homecoming and Student Programming Endowment



--Begin: Homecoming and Student Programming Endowment
UNION ALL
	   SELECT 
		 SPC.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 111 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN dbo.DIM_Constituent AS SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '20-90750'
											) AS Fund 
							
	   WHERE 
	        C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'Oklahoma State University'
		AND SPC.ConstituentID IS NOT NULL
--End: Homecoming and Student Programming Endowment



--Begin: OSU Student Success Center
UNION ALL
	   SELECT 
		 C.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 112 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '20-73350'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'Oklahoma State University'
--End: OSU Student Success Center



--Begin: OSU Student Success Center
UNION ALL
	   SELECT 
		 SPC.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 112 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN dbo.DIM_Constituent AS SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '20-73350'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'Oklahoma State University'
		AND SPC.ConstituentID IS NOT NULL
--End: OSU Student Success Center



--Begin: CHS Excellence Fund
UNION ALL
	   SELECT 
		 C.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 113 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '31-21500'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'OSU-Center for Health Sciences'
--End: CHS Excellence Fund



--Begin: CHS Excellence Fund
UNION ALL
	   SELECT 
		 SPC.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 113 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN dbo.DIM_Constituent AS SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '31-21500'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'OSU-Center for Health Sciences'
		AND SPC.ConstituentID IS NOT NULL
--End: CHS Excellence Fund



--Begin: OSU-COM General Scholarship
UNION ALL
	   SELECT 
		 C.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 114 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '31-22500'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'OSU-Center for Health Sciences'
--End: OSU-COM General Scholarship



--Begin: OSU-COM General Scholarship
UNION ALL
	   SELECT 
		 SPC.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 114 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN dbo.DIM_Constituent AS SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '31-22500'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'OSU-Center for Health Sciences'
		AND SPC.ConstituentID IS NOT NULL
--End: OSU-COM General Scholarship



--Begin: OSUIT Excellence Fund
UNION ALL
	   SELECT 
		 C.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 115 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '29-93300'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'OSU-Institute of Technology'
--End: OSUIT Excellence Fund



--Begin: OSUIT Excellence Fund
UNION ALL
	   SELECT 
		 SPC.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 115 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN dbo.DIM_Constituent AS SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '29-93300'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'OSU-Institute of Technology'
		AND SPC.ConstituentID IS NOT NULL
--End: OSUIT Excellence Fund



--Begin: OSUIT Scholarship Fund
UNION ALL
	   SELECT 
		 C.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 116 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '29-99970'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'OSU-Institute of Technology'
--End: OSUIT Scholarship Fund



--Begin: OSUIT Scholarship Fund
UNION ALL
	   SELECT 
		 SPC.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 116 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN dbo.DIM_Constituent AS SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '29-99970'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'OSU-Institute of Technology'
		AND SPC.ConstituentID IS NOT NULL
--End: OSUIT Scholarship Fund



--Begin: OSU - OKC Excellence Fund
UNION ALL
	   SELECT 
		 C.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 117 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '30-88500'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'OSU-Oklahoma City'
--End: OSU - OKC Excellence Fund



--Begin: OSU - OKC Excellence Fund
UNION ALL
	   SELECT 
		 SPC.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 117 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN dbo.DIM_Constituent AS SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '30-88500'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'OSU-Oklahoma City'
		AND SPC.ConstituentID IS NOT NULL
--End: OSU - OKC Excellence Fund



--Begin: OSU-Oklahoma City General Scholarship Fund
UNION ALL
	   SELECT 
		 C.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 118 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '30-93100'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'OSU-Oklahoma City'
--End: OSU-Oklahoma City General Scholarship Fund



--Begin: OSU-Oklahoma City General Scholarship Fund
UNION ALL
	   SELECT 
		 SPC.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 118 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								INNER JOIN dbo.DIM_Constituent AS SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID
								INNER JOIN #Education AS E ON C.ConstituentDimID = E.ConstituentDimID
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '30-93100'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
		AND E.SchoolName = 'OSU-Oklahoma City'
		AND SPC.ConstituentID IS NOT NULL
--End: OSU-Oklahoma City General Scholarship Fund



--Begin: General Scholarship fund
UNION ALL
	   SELECT 
		 C.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 119 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM  
	     dbo.DIM_Constituent C 
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '20-24400'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
--End: General Scholarship fund


--Begin: OSU Pettherapy program
UNION ALL
	   SELECT 
		 C.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 120 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '20-81600'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
--End: OSU Pettherapy program
--Begin: Veterans Emergency fund
UNION ALL
       SELECT 
		 C.ConstituentDimID
	   , Fund.FundIdentifier
	   , Fund.FundDescription
	   , 121 AS DesignationsOrder
	   , 'Specified Fund' AS DataSource

	   FROM 
	     dbo.DIM_Constituent C 
								CROSS JOIN
											(
												SELECT
												  FundIdentifier
												, FundDescription

												FROM
												  dbo.DIM_Fund

												WHERE 
													FundIdentifier = '20-19650'
											) AS Fund 
							
	   WHERE 
	       C.ConstituentID IS NOT NULL
		AND C.KeyIndicator = 'I'
		AND C.IsInactive = 'No'
--End: Veterans Emergency fund

	) AS Q






/*============================================================================================
--
--Description: The Normal Fund Suggestions
--
============================================================================================*/

--Delete the #table if it exists
IF OBJECT_ID('tempdb..#DesignationInitialControl') IS NOT NULL
    DROP TABLE        #DesignationInitialControl
GO

--Create the #DesignationData table
CREATE TABLE #DesignationInitialControl
									   (
											  PKID              INT          NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
											, ConstituentDimID  VARCHAR(20)  NOT NULL
											, FundIdentifier    VARCHAR(20)  NOT NULL
											, DesignationsOrder INT          NOT NULL
											, DataSource        VARCHAR(100) NOT NULL
									   )

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #DesignationInitialControl', 0, 1, 56) WITH NOWAIT
INSERT INTO            #DesignationInitialControl
SELECT
  Q.ConstituentDimID
, Q.FundIdentifier
, Q.DesignationsOrder
, Q.DataSource

FROM
    (
--Begin: AG defined fund with most total amount given
	   SELECT 
		 P.ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , 1 AS DesignationsOrder
	   , 'AG fund that were given to most by amount' AS DataSource

	   FROM 
		#FundsGiventoMostMoney AS P
									INNER JOIN dbo.DIM_Fund AS F ON P.FundIdentifierTrans = F.FundIdentifier
			
	   WHERE 
	       P.Seq = 1
--End: AG defined fund with most total amount given



--Begin: 3 most Annual Giving defined fund given to most frequently
UNION ALL
	   SELECT 
		 P.ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , P.Seq+1 AS DesignationsOrder  --This should give the values 2,3,4
	   , '3 Most AG funds that were given to most frequently' AS DataSource

	   FROM 
		#FundsGiventoMostFrequently AS P
										INNER JOIN dbo.DIM_Fund AS F ON P.FundIdentifierTrans = F.FundIdentifier
			
	   WHERE 
	       P.Seq <= 3
--End: 3 most Annual Giving defined fund given to most frequently



--Begin: Fund Suggestions that are the same between the Normal group and the test group
UNION ALL
	   SELECT 
		 ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , DesignationsOrder 
	   , DataSource

	   FROM 
		#DesignationDataBoth AS P
									INNER JOIN dbo.DIM_Fund AS F ON P.FundIdentifier = F.FundIdentifier
--End: Fund Suggestions that are the same between the Normal group and the test group
	) AS Q 

--WHERe Q.FundIdentifier IN (SELECT FundIdentifier FROM #AGFunds)


/*============================================================================================
--
--Description: Test Fund Suggestions
--
============================================================================================*/

--Delete the #table if it exists
IF OBJECT_ID('tempdb..#FundSuggestionData_Initial') IS NOT NULL
    DROP TABLE #FundSuggestionData_Initial
GO

--Create the #temp table
CREATE TABLE #FundSuggestionData_Initial
							   (
									  PKID              INT          NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
									, ConstituentDimID  VARCHAR(20)  NOT NULL
									, FundIdentifier    VARCHAR(20)  NOT NULL
									, DesignationsOrder INT          NOT NULL
									, DataSource        VARCHAR(100) NOT NULL
							   )

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #FundSuggestionData_Initial', 0, 1, 56) WITH NOWAIT
INSERT INTO            #FundSuggestionData_Initial
SELECT
  Q.ConstituentDimID
, Q.FundIdentifier
, Q.DesignationsOrder
, Q.DataSource

FROM
    (
--Begin: First four items for the test fund array
	   SELECT 
		 P.ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , P.Seq AS DesignationsOrder
	   , 'First three items for the test fund array' AS DataSource

	   FROM 
		 #FundTestArrayFunds AS P
									INNER JOIN dbo.DIM_Fund AS F ON P.FundIdentifierTrans = F.FundIdentifier
			
	   WHERE 
	       P.Seq <=4
--End: First three items for the test fund array



--Begin: Fund Suggestions that are the same between the Normal group and the test group
UNION ALL
	   SELECT 
		 ConstituentDimID
	   , F.FundIdentifier
	   , F.FundDescription
	   , DesignationsOrder 
	   , DataSource

	   FROM 
		#DesignationDataBoth AS P
									INNER JOIN dbo.DIM_Fund AS F ON P.FundIdentifier = F.FundIdentifier
--End: Fund Suggestions that are the same between the Normal group and the test group
	) AS Q

--WHERe Q.FundIdentifier IN (SELECT FundIdentifier FROM #AGFunds)



/*============================================================================================
--
--Description: Dedup the Designations and assign a sequence number by smallest designation number - This is for the Initial and Control Fund Array
--
============================================================================================*/

--Delete the #table if it exists
IF OBJECT_ID('tempdb..#DesignationswithRankingInitialControl') IS NOT NULL
    DROP TABLE        #DesignationswithRankingInitialControl
GO

--Create the #temp table
CREATE TABLE #DesignationswithRankingInitialControl
													(
														  PKID             INT          NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
														, ConstituentDimID INT          NOT NULL 
														, FundIdentifier   VARCHAR(20)  NOT NULL
														, FundDescription  VARCHAR(255) NOT NULL
														, Seq              INT          NOT NULL
													)


RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #DesignationswithRankingInitialControl', 0, 1, 56) WITH NOWAIT
INSERT INTO            #DesignationswithRankingInitialControl
SELECT
  Q.ConstituentDimID
, Q.FundIdentifier
, Q.FundDescription
, ROW_NUMBER() OVER( PARTITION BY Q.ConstituentDimID ORDER BY MIN(Q.Seq) ASC) AS Seq						
								
FROM
	   (  
		  SELECT
		    D.ConstituentDimID
		  , F.FundIdentifier
		  , F.FundDescription
		  , D.DesignationsOrder
		  , D.DataSource
		  , ROW_NUMBER() OVER( PARTITION BY D.ConstituentDimID ORDER BY D.DesignationsOrder ASC) AS Seq	

		  FROM
		    #DesignationInitialControl AS D
											INNER JOIN dbo.DIM_Fund F ON D.FundIdentifier = F.FundIdentifier
									
		  --WHERE
			 -- F.IsInactive = 'No'
	   ) AS Q
					   INNER JOIN
								(
									SELECT DISTINCT
									  ConstituentDimID

									FROM
									  #LTOBGivingPerFiscalYear

									WHERE
									  --FiscalYear BETWEEN 2015 AND 2016
									  FiscalYear BETWEEN 2016 AND 2017
								) AS IncludeList ON Q.ConstituentDimID = IncludeList.ConstituentDimID			


GROUP BY
  Q.ConstituentDimID
, Q.FundIdentifier
, Q.FundDescription

--Create an index on ConstituentID and Seq, this was just a performance boost.
CREATE INDEX IDX_#DesignationswithRankingInitialControl_Multi ON #DesignationswithRankingInitialControl(ConstituentDimID, Seq) INCLUDE (FundIdentifier, FundDescription)










/*============================================================================================
--
--Description: Dedup the Designations and assign a sequence number by smallest designation number - This is for the normal fund Array
--
============================================================================================*/

--Delete the #table if it exists
IF OBJECT_ID('tempdb..#FundSuggestionData_Final') IS NOT NULL
    DROP TABLE       #FundSuggestionData_Final
GO

--Create the #temp table
CREATE TABLE #FundSuggestionData_Final
											(
												  PKID             INT          NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
												, ConstituentDimID INT          NOT NULL 
												, FundIdentifier   VARCHAR(20)  NOT NULL
												, FundDescription  VARCHAR(255) NOT NULL
												, Seq              INT          NOT NULL
											)


RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #FundSuggestionData_Final', 0, 1, 56) WITH NOWAIT
INSERT INTO            #FundSuggestionData_Final
SELECT
  Q.ConstituentDimID
, Q.FundIdentifier
, Q.FundDescription
, ROW_NUMBER() OVER( PARTITION BY Q.ConstituentDimID ORDER BY MIN(Q.Seq) ASC) AS Seq						
								
FROM
	   (  
		  SELECT
		    D.ConstituentDimID
		  , F.FundIdentifier
		  , F.FundDescription
		  , D.DesignationsOrder
		  , D.DataSource
		  , ROW_NUMBER() OVER( PARTITION BY D.ConstituentDimID ORDER BY D.DesignationsOrder ASC) AS Seq	

		  FROM
		    #FundSuggestionData_Initial AS D
									INNER JOIN dbo.DIM_Fund F ON D.FundIdentifier = F.FundIdentifier
									
		  --WHERE
			 -- F.IsInactive = 'No'
	   ) AS Q
					   INNER JOIN
								(
									SELECT DISTINCT
									  ConstituentDimID

									FROM
									  #LTOBGivingPerFiscalYear

									WHERE
									  FiscalYear BETWEEN 2015 AND 2016
								) AS IncludeList ON Q.ConstituentDimID = IncludeList.ConstituentDimID			


GROUP BY
  Q.ConstituentDimID
, Q.FundIdentifier
, Q.FundDescription

--Create an index on ConstituentID and Seq, this was just a performance boost.
CREATE INDEX IDX_#DesignationswithRankingTest_Multi ON #FundSuggestionData_Final(ConstituentDimID, Seq) INCLUDE (FundIdentifier, FundDescription)


--/*============================================================================================
----
----Description: Marketing Segment
----
--============================================================================================*/
----ask bj how to get marketing segment
---- #temp table for 4 + years lapsed donors
----Delete the #table if it exists
--IF OBJECT_ID('tempdb..#MarketingSegment_16-17') IS NOT NULL
--    DROP TABLE        [#MarketingSegment_16-17]
--GO

----Create the #temp table
--CREATE TABLE [#MarketingSegment_16-17]
--									(
--										  ConstituentDimID INT          NOT NULL PRIMARY KEY CLUSTERED
--										--, MarketingSegment  VARCHAR(50) NOT NULL
--										, FiscalYear INT
--									)


--RAISERROR ('', 0, 1, 56) WITH NOWAIT
--RAISERROR ('', 0, 1, 56) WITH NOWAIT
--RAISERROR ('Populating#MarketingSegment_16-17', 0, 1, 56) WITH NOWAIT
--INSERT INTO            [#MarketingSegment_16-17]

--SELECT
--  IE.ConstituentDimID
----, QL2.MarketingSegment
--, LTOB.FiscalYear
--FROM
--  #IncludeList_minus_Excludelist IE
----query for fy16 and 17 donors  (use the ltob table)
--									INNER JOIN
--											  #LTOBGivingPerFiscalYear LTOB ON IE.ConstituentDimID = LTOB.ConstituentDimID

--											WHERE
--												LTOB.FiscalYear IN (2016, 2017)


----#temp table for 4 + years lapsed donors
----Delete the #table if it exists
--IF OBJECT_ID('tempdb..#MarketingSegment_4PLUS') IS NOT NULL
--    DROP TABLE        #MarketingSegment_4PLUS
--GO

----Create the #temp table
--CREATE TABLE #MarketingSegment_4PLUS
--									(
--										  ConstituentDimID INT          NOT NULL PRIMARY KEY CLUSTERED
--										--, MarketingSegment  VARCHAR(50) NOT NULL
--										, FiscalYear INT
--									)


--RAISERROR ('', 0, 1, 56) WITH NOWAIT
--RAISERROR ('', 0, 1, 56) WITH NOWAIT
--RAISERROR ('Populating #MarketingSegment_4PLUS', 0, 1, 56) WITH NOWAIT
--INSERT INTO           #MarketingSegment_4PLUS


--SELECT
--  IE.ConstituentDimID
---- QL2.MarketingSegment
--, LTOB.FiscalYear
--FROM
--  #IncludeList_minus_Excludelist IE
----query for fy16 and 17 donors  (use the ltob table)

--										INNER JOIN
--												  #LTOBGivingPerFiscalYear LTOB ON IE.ConstituentDimID = LTOB.ConstituentDimID

--												WHERE

--													MAX(LTOB.FiscalYear) <=2012	


---- #temp table for 1YRG2-3LAPSED	
----Delete the #table if it exists
--IF OBJECT_ID('tempdb..#MarketingSegment_1YRG2-3LAPSED') IS NOT NULL
--    DROP TABLE        [#MarketingSegment_1YRG2-3LAPSED]
--GO

----Create the #temp table
--CREATE TABLE [#MarketingSegment_1YRG2-3LAPSED]
--									(
--										  ConstituentDimID INT          NOT NULL --PRIMARY KEY CLUSTERED
--										--, MarketingSegment  VARCHAR(50) NOT NULL
--										, FiscalYear INT
--									)


--RAISERROR ('', 0, 1, 56) WITH NOWAIT
--RAISERROR ('', 0, 1, 56) WITH NOWAIT
--RAISERROR ('Populating #MarketingSegment_1YRG2-3LAPSED', 0, 1, 56) WITH NOWAIT
--INSERT INTO           [#MarketingSegment_1YRG2-3LAPSED]

--SELECT
--  IE.ConstituentDimID
----, QL2.MarketingSegment
--, LTOB.FiscalYear
--FROM
--  #IncludeList_minus_Excludelist IE
----query for fy16 and 17 donors  (use the ltob table)
--										INNER JOIN
--												  #LTOBGivingPerFiscalYear LTOB ON IE.ConstituentDimID = LTOB.ConstituentDimID
--										LEFT OUTER JOIN
--														(
--																SELECT 
--																	 ConstituentDimID
--																   , SUM(CASE WHEN FiscalYear = 2017 THEN Amount ELSE 0 END) AS FY17
--																   , SUM(CASE WHEN FiscalYear = 2016 THEN Amount ELSE 0 END) AS FY16

--																FROM
--																	#LTOBGivingPerFiscalYear
--																GROUP BY
--																	ConstituentDimID	
--														 ) AS AGFY ON IE.ConstituentDimID = AGFY.ConstituentDimID

--										LEFT OUTER JOIN
--														  (
--																SELECT 
--																	  ConstituentDimID
--																	, COUNT(DISTINCT FiscalYear) TotalYear
--																FROM
--																	Report_DW.dbo.OSUF_Comp_Production_and_Receipts CPR 
--																WHERE 
--																	CPR.IsAGGift = 'Yes'
--																	--AND CPR.FiscalYear BETWEEN 2006 AND 2017
--																	AND CPR.CGPRAmount > 0
--																	AND CPR.DataSource IN ('Development', 'OSUAA Membership Dues', 'Recognition Credit')
--																GROUP BY ConstituentDimID
--														 ) OCPR ON IE.ConstituentDimID = OCPR.ConstituentDimID

--WHERE
--	LTOB.FiscalYear IN(2014,2015,2016)	
--	AND (AGFY.FY17=0 OR AGFY.FY16=0) 
--	AND OCPR.TotalYear<=1	


----#temp table for 2YRG2-3LAPSED
----Delete the #table if it exists
--IF OBJECT_ID('tempdb..#MarketingSegment_2YRG2-3LAPSED') IS NOT NULL
--    DROP TABLE        [#MarketingSegment_2YRG2-3LAPSED]
--GO

----Create the #temp table
--CREATE TABLE [#MarketingSegment_2YRG2-3LAPSED]
--									(
--										  ConstituentDimID INT          NOT NULL --PRIMARY KEY CLUSTERED
--										--, MarketingSegment  VARCHAR(50) NOT NULL
--										, FiscalYear INT
--									)


--RAISERROR ('', 0, 1, 56) WITH NOWAIT
--RAISERROR ('', 0, 1, 56) WITH NOWAIT
--RAISERROR ('Populating #MarketingSegment_2YRG2-3LAPSED', 0, 1, 56) WITH NOWAIT
--INSERT INTO           [#MarketingSegment_2YRG2-3LAPSED]
--SELECT
--  IE.ConstituentDimID
----, QL2.MarketingSegment
--, LTOB.FiscalYear
--FROM
--  #IncludeList_minus_Excludelist IE
----query for fy16 and 17 donors  (use the ltob table)
--										INNER JOIN
--										#LTOBGivingPerFiscalYear LTOB ON IE.ConstituentDimID = LTOB.ConstituentDimID
--										LEFT OUTER JOIN
--													(
--														SELECT 
--														  ConstituentDimID
--														, SUM(CASE WHEN FiscalYear = 2017 THEN Amount ELSE 0 END) AS FY17
--														, SUM(CASE WHEN FiscalYear = 2016 THEN Amount ELSE 0 END) AS FY16

--														FROM
--															#LTOBGivingPerFiscalYear
--														GROUP BY
--															ConstituentDimID	
--													) AS AGFY ON IE.ConstituentDimID = AGFY.ConstituentDimID
--									  LEFT OUTER JOIN
--													(
--														SELECT 
--																ConstituentDimID
--															, COUNT(DISTINCT FiscalYear) TotalYear
--														FROM
--															Report_DW.dbo.OSUF_Comp_Production_and_Receipts CPR 
--														WHERE 
--															CPR.IsAGGift = 'Yes'
--															--AND CPR.FiscalYear BETWEEN 2006 AND 2017
--															AND CPR.CGPRAmount > 0
--															AND CPR.DataSource IN ('Development', 'OSUAA Membership Dues', 'Recognition Credit')
--														GROUP BY ConstituentDimID
--													) OCPR ON IE.ConstituentDimID = OCPR.ConstituentDimID

--WHERE
--	LTOB.FiscalYear IN(2014,2015)	
--	AND (AGFY.FY17=0 OR AGFY.FY16=0) 
--	AND OCPR.TotalYear>=2				

IF OBJECT_ID('tempdb..#MarketingSegment') IS NOT NULL
    DROP TABLE        #MarketingSegment
GO

--Create the #temp table
CREATE TABLE #MarketingSegment
									(
										  ConstituentDimID INT          NOT NULL --PRIMARY KEY CLUSTERED
										, MarketingSegment  VARCHAR(50) NOT NULL
									)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #MarketingSegment', 0, 1, 56) WITH NOWAIT
INSERT INTO            #MarketingSegment
SELECT
  IE.ConstituentDimID
, CASE 
		WHEN FY1617Donors.ConstituentDimID IS NOT NULL THEN '16&17DONOR'
		WHEN DT.DPAGDonorTypeBucket = '4+ Year Lapsed' THEN '4PLUS'
		WHEN OCPR.TotalYear<=1 THEN '1YRG2-3LAPSED'
		WHEN OCPR.TotalYear>=2 THEN '2YRG2-3LAPSED'
		ELSE ''
  END AS MarketingSegment
FROM
  #IncludeList_minus_Excludelist IE
										INNER JOIN #DonorType AS DT ON IE.ConstituentDimID = DT.ConstituentDimID

										LEFT OUTER JOIN 
														(
															SELECT DISTINCT 
															  ConstituentDimID

															FROM 
															  #LTOBGivingPerFiscalYear

															WHERE 
															    FiscalYear IN (2016, 2017)
															AND Amount > 0
														) AS FY1617Donors ON IE.ConstituentDimID = FY1617Donors.ConstituentDimID
										LEFT OUTER JOIN
														(
															SELECT 
																	ConstituentDimID
																, SUM(CASE WHEN FiscalYear = 2017 THEN Amount ELSE 0 END) AS FY17
																, SUM(CASE WHEN FiscalYear = 2016 THEN Amount ELSE 0 END) AS FY16

															FROM
																#LTOBGivingPerFiscalYear

															--WHERE  FiscalYear IN(2014,2015)
															GROUP BY
																ConstituentDimID	
														 ) AS AGFY ON IE.ConstituentDimID = AGFY.ConstituentDimID

										LEFT OUTER JOIN
														  (
															SELECT 
																	ConstituentDimID
																, COUNT(DISTINCT FiscalYear) TotalYear
															FROM
																Report_DW.dbo.OSUF_Comp_Production_and_Receipts CPR 
															WHERE 
																CPR.IsAGGift = 'Yes'
																--AND CPR.FiscalYear BETWEEN 2006 AND 2017
																AND CPR.CGPRAmount > 0
																AND CPR.DataSource IN ('Development', 'OSUAA Membership Dues', 'Recognition Credit')
															GROUP BY ConstituentDimID
														 ) OCPR ON IE.ConstituentDimID = OCPR.ConstituentDimID
							 
/*============================================================================================
--
--Description: Ask array
--
============================================================================================*/
IF OBJECT_ID('tempdb..#AskArray') IS NOT NULL
    DROP TABLE        #AskArray
GO

CREATE TABLE #AskArray
						(
							  ConstituentDimID INT   NOT NULL PRIMARY KEY CLUSTERED
							, Ask1             MONEY
							, Ask2             MONEY
							, Ask3             MONEY
						)

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Populating #AskArray', 0, 1, 56) WITH NOWAIT
INSERT INTO            #AskArray
SELECT 
  Q.ConstituentDimID
, CASE 
		WHEN Q.Marketingsegment = '2YRG2-3LAPSED' AND Q.Ask1 > 75 AND Q.Ask1<250		THEN  200  --min
		WHEN Q.Marketingsegment = '2YRG2-3LAPSED' AND Q.Ask1 > 250 AND Q.Ask1<1000       THEN  1000
		WHEN Q.Marketingsegment = '2YRG2-3LAPSED' AND  Q.Ask1 > 1000      THEN  5000
		ELSE CAST(ROUND(Q.Ask1 /5,0)*5 AS MONEY)
  END AS 
Ask1

, CASE 
		WHEN Q.Marketingsegment = '2YRG2-3LAPSED' AND Q.Ask2 > 75 AND Q.Ask2<250       THEN  100  --min
		WHEN Q.Marketingsegment = '2YRG2-3LAPSED' AND Q.Ask2 > 250 AND Q.Ask2<1000       THEN  500
		WHEN Q.Marketingsegment = '2YRG2-3LAPSED' AND Q.Ask2 > 1000      THEN  2500
		ELSE CAST(ROUND(Q.Ask2 /5,0)*5 AS MONEY)																	 
  END AS 
Ask2																		 
																					 
, CASE 																				 
		WHEN Q.Marketingsegment = '2YRG2-3LAPSED' AND Q.Ask3 > 75 AND Q.Ask3<250      THEN  50  --min
		WHEN Q.Marketingsegment = '2YRG2-3LAPSED' AND Q.Ask3 > 250 AND Q.Ask3<1000       THEN  200
		WHEN Q.Marketingsegment = '2YRG2-3LAPSED' AND Q.Ask3 > 1000      THEN  1000										 
		ELSE CAST(ROUND(Q.Ask3 /5,0)*5 AS MONEY)																		     
  END AS 
Ask3

FROM
	(
		--Ask arrays are rounded to the nearest $5
		--
SELECT 
IL.ConstituentDimID,
		
  CASE 	
	      WHEN MS.Marketingsegment='4PLUS'                                                                          THEN 100																																							       
	      WHEN MS.Marketingsegment= '1YRG2-3LAPSED'                                                                 THEN 100	
	      WHEN MS.Marketingsegment = '2YRG2-3LAPSED' AND AGAveragePerYear.AVGAmount<=75                             THEN 100
          WHEN MS.Marketingsegment = '2YRG2-3LAPSED' AND AGAveragePerYear.AVGAmount BETWEEN 75 AND 250              THEN (AGAveragePerYear.AVGAmount)*2
	      WHEN MS.Marketingsegment = '2YRG2-3LAPSED' AND AGAveragePerYear.AVGAmount BETWEEN 250 AND 1000            THEN (AGAveragePerYear.AVGAmount)*1.5	
	      WHEN MS.Marketingsegment = '2YRG2-3LAPSED' AND AGAveragePerYear.AVGAmount >= 1000                         THEN (AGAveragePerYear.AVGAmount)*1.1	
					                                                                             																
					                                                                             																							       																																								       

END AS Ask1


, CASE     
           WHEN MS.Marketingsegment='4PLUS'                                                                          THEN 50																																							       
	       WHEN MS.Marketingsegment= '1YRG2-3LAPSED'                                                                 THEN 50	
	       WHEN MS.Marketingsegment = '2YRG2-3LAPSED' AND AGAveragePerYear.AVGAmount<=75                             THEN 50
           WHEN MS.Marketingsegment = '2YRG2-3LAPSED' AND AGAveragePerYear.AVGAmount BETWEEN 75 AND 250              THEN (AGAveragePerYear.AVGAmount)*1.1
	       WHEN MS.Marketingsegment = '2YRG2-3LAPSED' AND AGAveragePerYear.AVGAmount BETWEEN 250 AND 1000            THEN (AGAveragePerYear.AVGAmount)*1.1	
	       WHEN MS.Marketingsegment = '2YRG2-3LAPSED' AND AGAveragePerYear.AVGAmount >= 1000                         THEN (AGAveragePerYear.AVGAmount)*1	
					                                                                             															
END AS Ask2



, CASE
           WHEN MS.Marketingsegment='4PLUS'                                                                          THEN 25																																							       
	       WHEN MS.Marketingsegment= '1YRG2-3LAPSED'                                                                 THEN 25	
	       WHEN MS.Marketingsegment = '2YRG2-3LAPSED' AND AGAveragePerYear.AVGAmount<=75                             THEN 25
           WHEN MS.Marketingsegment = '2YRG2-3LAPSED' AND AGAveragePerYear.AVGAmount BETWEEN 75 AND 250              THEN (AGAveragePerYear.AVGAmount)*0.5
	       WHEN MS.Marketingsegment = '2YRG2-3LAPSED' AND AGAveragePerYear.AVGAmount BETWEEN 250 AND 1000            THEN (AGAveragePerYear.AVGAmount)*0.5
	       WHEN MS.Marketingsegment = '2YRG2-3LAPSED' AND AGAveragePerYear.AVGAmount >= 1000                         THEN (AGAveragePerYear.AVGAmount)*0.5	

END AS Ask3
, MS.Marketingsegment AS Marketingsegment
--		  ,DT.DPAGDonorTypeBucket AS DPAGDonorTypeBucket 

FROM
#IncludeList_minus_ExcludeList AS IL
											--Cumulative Giving in the last year they gave
											LEFT OUTER JOIN 
														(
															SELECT 
																ConstituentDimID
															, DPAGDonorTypeBucket


															FROM
																#DonorType
														) AS DT ON IL.ConstituentDimID = DT.ConstituentDimID


											LEFT OUTER JOIN 
														(
															SELECT 
																ConstituentDimID
															, MarketingSegment


															FROM
																#MarketingSegment
														) AS MS ON IL.ConstituentDimID = MS.ConstituentDimID


											--AnnualGiving in FY17,FY16
	                                        LEFT OUTER JOIN 
															(
																SELECT 
																	ConstituentDimID
																, SUM(CASE WHEN FiscalYear = 2017 THEN Amount ELSE 0 END) AS FY17
																, SUM(CASE WHEN FiscalYear = 2016 THEN Amount ELSE 0 END) AS FY16

																FROM
																	#LTOBGivingPerFiscalYear

																		

																GROUP BY
																	ConstituentDimID	
															) AS AGFY ON IL.ConstituentDimID = AGFY.ConstituentDimID


											--AGFY ALL
											LEFT OUTER JOIN 
														(
															SELECT 
																ConstituentDimID
															, COUNT(DISTINCT FiscalYear) TotalYear

															FROM
																#LTOBGivingPerFiscalYear

																

															GROUP BY
																ConstituentDimID	
														) AS AGFYAll ON IL.ConstituentDimID = AGFYAll.ConstituentDimID


	                                        LEFT OUTER JOIN 
															(
															SELECT 
																ConstituentDimID
															, SUM(Amount) AS SUMAmount
															, AVG(Amount) AS AVGAmount
																		
															FROM 
																(																		
																	SELECT 
																	  ConstituentDimID
																	, FiscalYear
																	, SUM(Amount) AS Amount
																	, AVG(Amount) AS AVGAmount
																	FROM #LTOBGivingperFiscalyear
																		

																	GROUP BY
																	  ConstituentDimID
																	, FiscalYear

																) AS Q

														GROUP BY 
															ConstituentDimID
															) AS AGAveragePerYear ON IL.ConstituentDimID = AGAveragePerYear.ConstituentDimID

															
																								

) AS Q
GO


/*============================================================================================
--
--Description: Main Query
--                    
==============================================================================================*/

RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('', 0, 1, 56) WITH NOWAIT
RAISERROR ('Final Query!!!!', 0, 1, 56) WITH NOWAIT
SELECT
  C.ConstituentID               
, C.Title				        
, C.FirstName                   AS 'First Name'
, C.Surname                     AS 'Last Name'  
, COALESCE(C.Nickname, '')      AS Nickname
, COALESCE(C.Suffix, '')        AS Suffix
, C.Salutation
, C.Addressee                   AS 'Primary Addressee Format'
, COALESCE(MN.Mgr1, MN.Cl1, MN.DiscMgr, MN.DiscClMgr, '') AS 'Manager 1'
, COALESCE(MN.Mgr2, MN.Cl2, '') AS 'Manager 2'
, COALESCE(MN.Mgr3, MN.Cl3, '') AS 'Manager 3'
, C.Address1
, C.Address2
, C.Address3
, C.Address4
, C.Address5
, C.City
, C.State
, C.PostCode                   AS Zip
, COALESCE(C.Country, '')      AS Country

, 'A17SM-DM'                   AS 'Appeal Code + Package ID'
--, MS.MarketingSegment
, COALESCE(C.EmailAddress, '') AS Email
, COALESCE(Emp.FullName, '')   AS Employer
, COALESCE(Emp.Position, '')   AS 'Job Title'

, COALESCE(SPC.ConstituentID, '') AS 'Spouse ConstituentID'
, COALESCE(SPC.Title, '')         AS 'Spouse Title'
, COALESCE(SPC.FirstName, '')     AS 'Spouse First Name'
, COALESCE(SPC.Surname, '')       AS 'Spouse Last Name'
, COALESCE(SPC.Nickname, '')      AS 'Spouse Nickname'
, COALESCE(SPC.Suffix, '')        AS 'Spouse Suffix'
, COALESCE(Phones.HomePhone, '')  AS 'Home Phone'
, COALESCE(Phones.HomeCell, '')   AS 'Cell Phone'
, DT.DPAGDonorTypeBucket          AS 'Annual Giving Donor Type Bucket'

, NumAGGifts.theCount AS 'Number of years containing an annual giving defined gift'

, COALESCE(CAST(FYLastAGGift.FiscalYear AS VARCHAR(4)), '')   AS 'Fiscal Year of last Annual Giving defined gift'
, COALESCE(CAST(FYLastGift.FiscalYear AS VARCHAR(4)), '')     AS 'Fiscal Year of last gift'
, LastYear.theYear											  AS 'Fiscal year of last gift prior to FY17'
, TotalAmntgivingprior17.Amount                               AS 'Total amount of giving in year of last gift (prior to FY17)'  
, COALESCE(CAST(FY16Giving.Amount AS VARCHAR(100)), '')       AS 'Total Amount of FY16 Giving'
, COALESCE(CAST(FY17Giving.Amount AS VARCHAR(100)), '')       AS 'Total Amount of FY17 Giving'

, CASE 
		WHEN LoyaltyGiving.ConstituentDimID IS NULL THEN '0'
		ELSE LoyaltyGiving.AttributeDescription
  END AS 'OSU Foundation Loyalty Giving Number (or total number of years of giving)'

, COALESCE(FY17DonorType.DPAGDonorTypeBucket, '')             AS 'FY17 Annual Giving Donor Type Bucket'

--, COALESCE(MS.marketingsegment,'')                            AS 'Marketing Segment'
, COALESCE(Des1.FundDescription,'') AS 'Suggested Fund Description 1'
, COALESCE(Des1.FundIdentifier,'')  AS 'Suggested Fund ID 1'
, COALESCE(Des2.FundDescription,'') AS 'Suggested Fund Description 2'
, COALESCE(Des2.FundIdentifier,'')  AS 'Suggested Fund ID 2'
, COALESCE(Des3.FundDescription,'') AS 'Suggested Fund Description 3'
, COALESCE(Des3.FundIdentifier,'')  AS 'Suggested Fund ID 3'

, COALESCE(DesNormal1.FundDescription,'') AS 'Annual Giving defined fund Description given to most frequently'
, COALESCE(DesNormal1.FundIdentifier,'')  AS 'Annual Giving defined fund ID given to most frequently'
, COALESCE(DesNormal2.FundDescription,'') AS 'Annual Giving defined fund Description given to 2nd most frequently'
, COALESCE(DesNormal2.FundIdentifier,'')  AS 'Annual Giving defined fund ID given to 2nd most frequently'
, COALESCE(DesNormal3.FundDescription,'') AS 'Annual Giving defined fund Description given to 3rd most frequently'
, COALESCE(DesNormal3.FundIdentifier,'')  AS 'Annual Giving defined fund ID given to 3rd most frequently'

, AA.Ask1 AS Ask1
, AA.Ask2 AS Ask2
, AA.Ask3 AS Ask3


--, IncludeList.MarketingSegment
--, CASE WHEN IncludeList.MarketingSegment = 'Test Array' THEN Des1.FundIdentifier  ELSE DesNormal1.FundIdentifier  END AS 'Suggested Fund ID 1'
--, CASE WHEN IncludeList.MarketingSegment = 'Test Array' THEN Des1.FundDescription ELSE DesNormal1.FundDescription END AS 'Suggested Fund Description 1'
--, CASE WHEN IncludeList.MarketingSegment = 'Test Array' THEN Des2.FundIdentifier  ELSE DesNormal2.FundIdentifier  END AS 'Suggested Fund ID 2'
--, CASE WHEN IncludeList.MarketingSegment = 'Test Array' THEN Des2.FundDescription ELSE DesNormal2.FundDescription END AS 'Suggested Fund Description 2'
--, CASE WHEN IncludeList.MarketingSegment = 'Test Array' THEN Des3.FundIdentifier  ELSE DesNormal3.FundIdentifier  END AS 'Suggested Fund ID 3'
--, CASE WHEN IncludeList.MarketingSegment = 'Test Array' THEN Des3.FundDescription ELSE DesNormal3.FundDescription END AS 'Suggested Fund Description 3'



----IT only columns
--, 'A15SM' AS 'Appeal Code'
--, 'DM'    AS 'Package ID'

FROM
  dbo.DIM_Constituent C


					   --Marketing Segment, this also controls who is on the list.
					   INNER JOIN #MarketingSegment IncludeList ON C.ConstituentDimID = IncludeList.ConstituentDimID

					   --Spouse Information
					   LEFT OUTER JOIN dbo.DIM_Constituent SPC ON C.SpouseConstituentSystemID = SPC.ConstituentSystemID

					   --Manager Information
					   LEFT OUTER JOIN dbo.OSUF_ManagerName AS MN ON C.ConstituentDimID = MN.ConstituentDimID

					   --Employer Info
					   LEFT OUTER JOIN
									(
										SELECT
										  R.ConstituentDimID
										, C.FullName
										, R.Position

										FROM 
										dbo.DIM_ConstituentRelationship AS R
																				INNER JOIN dbo.DIM_Constituent AS C ON R.RelatedConstituentDimID = C.ConstituentDimID

										WHERE
											R.Relationship = 'Employer'
										AND R.Reciprocal = 'Employee'
										AND R.IsPrimary = 'Yes'
										AND C.FullName <> 'Employer Unknown'
									) AS Emp ON C.ConstituentDimID = Emp.ConstituentDimID


						--Phone Info
						LEFT OUTER JOIN #Phones AS Phones ON C.ConstituentDimID = Phones.ConstituentDimID


					   --Fiscal Year of last Annual Giving defined gift
					   LEFT OUTER JOIN 
										(
											SELECT
											  Q.ConstituentDimID
											, MAX(Q.FiscalYear) AS FiscalYear

											FROM
												(
													SELECT ConstituentDimID, FiscalYear
													FROM #ProductionGifts
													WHERE IsAGGift = 'Yes'
													AND IsMatchingGift = 'No'
												) AS Q

											GROUP BY 
											  Q.ConstituentDimID
										) AS FYLastAGGift ON C.ConstituentDimID = FYLastAGGift.ConstituentDimID


					   --Fiscal Year of last gift
					   LEFT OUTER JOIN 
										(
											SELECT
											  Q.ConstituentDimID
											, MAX(Q.FiscalYear) AS FiscalYear

											FROM
												(
													SELECT ConstituentDimID, GiftFiscalYear AS FiscalYear
													FROM #LTOBGifts

													UNION
													
													SELECT ConstituentDimID, 2016 AS FiscalYear
													FROM #FY17ProjectGifts
												) AS Q

											GROUP BY 
											  Q.ConstituentDimID
										) AS FYLastGift ON C.ConstituentDimID = FYLastGift.ConstituentDimID


					   --FY16 Giving
					   LEFT OUTER JOIN 
										(
											SELECT
											  ConstituentDimID
											, Amount

											FROM
											  #LTOBGivingPerFiscalYear

											WHERE
											    FiscalYear = 2016
										) AS FY16Giving ON C.ConstituentDimID = FY16Giving.ConstituentDimID


					   --FY17 Giving
					   LEFT OUTER JOIN 
										(
											SELECT
											  ConstituentDimID
											, Amount

											FROM
											  #LTOBGivingPerFiscalYear

											WHERE
											    FiscalYear = 2017
										) AS FY17Giving ON C.ConstituentDimID = FY17Giving.ConstituentDimID


					   --Loyality Giving
					   LEFT OUTER JOIN
										(
											SELECT
											  ConstituentDimID
											, AttributeDescription

											FROM
											  dbo.DIM_ConstituentAttribute

											WHERE
												AttributeCategory = 'Loyalty Giving'
											AND Comments = 'OSU Foundation'
										) AS LoyaltyGiving ON C.ConstituentDimID = LoyaltyGiving.ConstituentDimID


						--FY15 DonorType
						LEFT OUTER JOIN
										(
											SELECT
												ConstituentDimID
											, DPAGDonorTypeBucket

											FROM 
												#DonorType

											WHERE
												FiscalYear = 2015
										) AS FY15DonorType ON C.ConstituentDimID = FY15DonorType.ConstituentDimID


						--FY17 DonorType
						LEFT OUTER JOIN
										(
											SELECT
											  ConstituentDimID
											, DPAGDonorTypeBucket

											FROM 
												#DonorType

											WHERE
												FiscalYear = 2017
										) AS FY17DonorType ON C.ConstituentDimID = FY17DonorType.ConstituentDimID

						--DonorType Bucket
						LEFT OUTER JOIN  #DonorType AS DT ON C.ConstituentDimID=DT.ConstituentDimID


						----Marketing Segment
						--LEFT OUTER JOIN #MarketingSegment AS MS ON C.ConstituentDimID=MS.ConstituentDimID

						--Initial and Control Designation Suggestions
						--LEFT OUTER JOIN #DesignationswithRankingInitialControl AS DesNormal1 ON C.ConstituentDimID = DesNormal1.ConstituentDimID AND DesNormal1.Seq = 1
						--LEFT OUTER JOIN #DesignationswithRankingInitialControl AS DesNormal2 ON C.ConstituentDimID = DesNormal2.ConstituentDimID AND DesNormal2.Seq = 2
						--LEFT OUTER JOIN #DesignationswithRankingInitialControl AS DesNormal3 ON C.ConstituentDimID = DesNormal3.ConstituentDimID AND DesNormal3.Seq = 3 
						
						--Test Designation Suggestions
						LEFT OUTER JOIN #FundSuggestionData_Final   AS   Des1 ON C.ConstituentDimID =   Des1.ConstituentDimID AND   Des1.Seq = 1
						LEFT OUTER JOIN #FundSuggestionData_Final   AS   Des2 ON C.ConstituentDimID =   Des2.ConstituentDimID AND   Des2.Seq = 2
						LEFT OUTER JOIN #FundSuggestionData_Final   AS   Des3 ON C.ConstituentDimID =   Des3.ConstituentDimID AND   Des3.Seq = 3 

						LEFT OUTER JOIN
											(
												SELECT 
												  ConstituentDimID
											    , COUNT(DISTINCT FiscalYear) AS theCount

												FROM 
												  #ProductionGifts

												WHERE 
												  Amount > 0 AND IsAGGift='Yes'
												
												GROUP BY ConstituentDimID
											)  AS NumAGGifts ON C.ConstituentDimID = NumAGGifts.ConstituentDimID

						LEFT OUTER JOIN
											(
												SELECT 
												  ConstituentDimID
											    , MAX(DISTINCT FiscalYear) AS theYear

												FROM 
												  #ProductionGifts

												WHERE 
												  Amount > 0 AND FiscalYear<>2017
												
												GROUP BY ConstituentDimID
											)  AS LastYear ON C.ConstituentDimID = LastYear.ConstituentDimID

						LEFT OUTER JOIN
						                  (
						                       SELECT
											         ConstituentDimID
												   , SUM(Amount) AS Amount
											       
												   FROM
												   #ProductionGifts

												   WHERE 
												     Amount>0 AND FiscalYear<>2017
												   GROUP BY ConstituentDimID

										    ) AS TotalAmntgivingprior17 ON C.ConstituentDimID=TotalAmntgivingprior17.ConstituentDimID 

						LEFT OUTER JOIN #MarketingSegment MS ON C.ConstituentDimID=MS.ConstituentDimID

						LEFT OUTER JOIN #AskArray AA ON C.ConstituentDimID=AA.ConstituentDimID
ORDER BY 
  CAST(C.ConstituentID AS INT)





/*
--Fund array Analysis, which funds need 
SELECT DISTINCT
  Designation.FundIdentifier
, F.FundDescription
, COALESCE(College.AttributeDescription, '') AS College
, COALESCE(Department.AttributeDescription, '') AS Department


FROM
  dbo.DIM_Constituent C


					   INNER JOIN #MarketingSegment IncludeList ON C.ConstituentDimID = IncludeList.ConstituentDimID

						INNER JOIN
									(
										SELECT N.ConstituentDimID, N.FundIdentifier
										FROM #DesignationswithRankingInitialControl AS N INNER JOIN #MarketingSegment AS M ON N.ConstituentDimID = M.ConstituentDimID
										WHERE N.Seq <= 10
										AND M.MarketingSegment <> 'Test Array'

										UNION
										SELECT N.ConstituentDimID, N.FundIdentifier
										FROM #DesignationswithRankingTest AS N INNER JOIN #MarketingSegment AS M ON N.ConstituentDimID = M.ConstituentDimID
										WHERE N.Seq <= 10
										AND M.MarketingSegment = 'Test Array'
									) AS Designation ON C.ConstituentDimID = Designation.ConstituentDimID


						INNER JOIN dbo.DIM_Fund AS F ON Designation.FundIdentifier = F.FundIdentifier

						LEFT OUTER JOIN 
										(
											SELECT
											  FundDimID
											, AttributeDescription

											FROM
											  dbo.DIM_FundAttribute

											WHERE
											    AttributeCategory = 'College'
										) AS College ON F.FundDimID = College.FundDimID


						LEFT OUTER JOIN 
										(
											SELECT
											  FundDimID
											, AttributeDescription

											FROM
											  dbo.DIM_FundAttribute

											WHERE
											    AttributeCategory = 'Department'
										) AS Department ON F.FundDimID = Department.FundDimID

						LEFT OUTER JOIN #AGFunds AS AGF ON Designation.FundIdentifier = AGF.FundIdentifier

					  
WHERE
    AGF.FundDimID IS NULL





SELECT T.* 
FROM 
  MikesTest.[dbo].[FY16StatementMailerFundTranslation] AS T
															LEFT OUTER JOIN OSUF_RE_DW.dbo.OSUF_CampusCall_SolicitableFunds AS SF ON T.SuggestedFundIdentifier = SF.Designation


WHERE SF.Designation IS NULL



SELECT
  FundIdentifier

FROM 
  MikesTest.[dbo].[FY16StatementMailerFundTranslation] AS T

Group by Fundidentifier

having count(1) > 1



*/

								


