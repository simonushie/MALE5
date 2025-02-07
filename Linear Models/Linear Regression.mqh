//+------------------------------------------------------------------+
//|                                            Linear Regression.mqh |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Omega Joctan"
#property link      "https://www.mql5.com/en/users/omegajoctan" 

//+------------------------------------------------------------------+

#include <MALE5\metrics.mqh>
#include <MALE5\MatrixExtend.mqh>
#include <MALE5\preprocessing.mqh>

//+------------------------------------------------------------------+

class CLinearRegression
  {  
   protected:
                        bool istrained;          
                        bool checkIsTrained(string func)
                          {
                            if (!istrained)
                              {
                                Print(func," Tree not trained, Call fit_GradDescent function first to train the model");
                                return false;   
                              }
                            return (true);
                          }
                          
                        double TrimNumber(double num)
                         {
                            if (num>=1e4) 
                              return 1e4; 
                            else if (num<=-1e4) 
                              return -1e4; 
                            else 
                              return num;
                         }
                           
                        double dx_wrt_bo(matrix &x, vector &y);
                        vector dx_wrt_b1(matrix &x, vector &y);
                        
       
   public:
                        matrix Betas;   //Coefficients matrix
                        vector Betas_v; //Coefficients vector 
                        
                        //double residual_value;  //Mean residual value
                        //vector Residuals;
                        
                        CLinearRegression(void);
                       ~CLinearRegression(void);
                       
                        void fit_LeastSquare(matrix &x, vector &y); //Least squares estimator
                        void fit_GradDescent(matrix &x, vector &y, double alpha, uint epochs = 1000); //LR by Gradient descent
                        
                        double predict(vector &x); 
                        vector predict(matrix &x);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLinearRegression::CLinearRegression(void) : istrained(false)
 {
       
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CLinearRegression::fit_LeastSquare(matrix &x, vector &y)
 { 
  matrix YMatrix = {};
  YMatrix = MatrixExtend::VectorToMatrix(y);
    
    ulong rows = y.Size(); 
    ulong cols = x.Cols();
    
    if (rows != x.Rows())
      {
         Print(__FUNCTION__," FATAL: Unbalanced rows ",rows," in the independent vector and x matrix of ",x.Rows()," rows");
         return;
      }
      
//---

    matrix design = MatrixExtend::DesignMatrix(x);
    
//--- XTX
    
    matrix XT = design.Transpose();
    
    matrix XTX = XT.MatMul(design);
    
//--- Inverse XTX

    matrix InverseXTX = XTX.Inv();
    
//--- Finding XTY
   
    matrix XTY = XT.MatMul(YMatrix);

//--- Coefficients
   
   Betas = InverseXTX.MatMul(XTY); 
   
   Betas_v = MatrixExtend::MatrixToVector(Betas);
   
   #ifdef DEBUG_MODE 
        Print("Betas\n",Betas);
   #endif 
   
   istrained = true;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CLinearRegression::fit_GradDescent(matrix &x, vector &y, double alpha, uint epochs = 1000)
 {              
    ulong rows = y.Size();
    ulong cols = x.Cols();
    
    if (rows != x.Rows())
      {
         Print("FATAL: Unbalanced rows in the independent vector and x matrix");
         return;
      }
    
    Betas_v.Resize(cols+1);

//---
     #ifdef DEBUG_MODE  
        Print("\nTraining a Linear Regression Model with Gradient Descent\n");
     #endif 
//---
     
     Betas_v.Fill(0.0);
     vector pred_v;
     
     for (ulong i=0; i<epochs; i++)
       {
         istrained = true;        
         
         double bo = dx_wrt_bo(x,y);

         Betas_v[0] = Betas_v[0] - (alpha * bo);
         //printf("----> dx_wrt_bo | Intercept = %.8f | Real Intercept = %.8f",bo,Betas_v[0]);
         
         vector dx = dx_wrt_b1(x,y); 

//---

          for (ulong j=0; j<dx.Size(); j++)
            {
               //Print("out at iterations Betas _v ",Betas_v);
                
                  Betas_v[j+1] = Betas_v[j+1] - (alpha * dx[j]);
                  
                  //printf("k %d | ----> dx_wrt_b%d | Slope = %.8f | Real Slope = %.8f",j,j,dx[j],Betas_v[j+1]); 
            }
         
//---

            Betas = MatrixExtend::VectorToMatrix(Betas_v);
            pred_v = predict(x);
            
            MatrixExtend::NormalizeVector(dx,5);
            
            printf("epoch[%d/%d] Loss %.5f Accuracy = %.3f",i+1,epochs,TrimNumber(Metrics::mse(y, pred_v)),TrimNumber(Metrics::r_squared(y,pred_v)));        
       } 

    Betas = MatrixExtend::VectorToMatrix(Betas_v);
    
//---

    #ifdef DEBUG_MODE 
        MatrixExtend::NormalizeVector(Betas_v,5);
        Print("Coefficients ",Betas_v);
    #endif 
    
    istrained = true;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CLinearRegression::~CLinearRegression(void)
 {   
   
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CLinearRegression::dx_wrt_bo(matrix &x, vector &y)
 {    
   double mx=0, sum=0;
   for (ulong i=0; i<x.Rows(); i++)
      {          
          mx = predict(x.Row(i));
          
          sum += (y[i] - mx);  
      }  
   
   return(-2*sum);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
vector CLinearRegression::dx_wrt_b1(matrix &x, vector &y)
 { 
   vector dx_vector(Betas_v.Size()-1);
   //Print("dx_vector.Size() = ",dx_vector.Size());
   
    double mx=0, sum=0;
   
    for (ulong b=0; b<dx_vector.Size(); b++)  
     {
       ZeroMemory(sum);
       
       for (ulong i=0; i<x.Rows(); i++)
         {             
            //Print("<<<    >>> intercept = ",mx," Betas_v ",Betas_v,"\n");
            mx = predict(x.Row(i));            

//---

            sum += (y[i] - mx) * x[i][b];  
            //PrintFormat("%d xMatrix %.5f",i,x[i][b]); 
          
            dx_vector[b] = -2*sum;  
        }
    }
      
    return dx_vector;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CLinearRegression::predict(vector &x)
 {   
   if (!checkIsTrained(__FUNCTION__))
     return 0;
   
   double pred_value =0; 
   double intercept = Betas_v[0];
   
   if (Betas_v.Size() == 0)
      {
         Print(__FUNCTION__,"Err, No coefficients available for LR model\nTrain the model before attempting to use it");
         return(0);
      }
   
    else
      { 
        if (x.Size() != Betas_v.Size()-1)
          Print(__FUNCTION__,"Err, X vars not same size as their coefficients vector ");
        else
          {
            for (ulong i=1; i<Betas_v.Size(); i++) 
               pred_value += x[i-1] * Betas_v[i];  
               
            pred_value += intercept; // + residual_value; 
          }
      }
    return  pred_value;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
vector CLinearRegression::predict(matrix &x)
 {
   vector pred_v(x.Rows());
   vector x_vec;
   
    for (ulong i=0; i<x.Rows(); i++)
     {
       x_vec = x.Row(i);
       pred_v[i] = predict(x_vec);
     }
   
   return pred_v;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
